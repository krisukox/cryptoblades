<template>
  <div class="wrapper">
    <nav>
      <div class="navTitle">Arena</div>
      <div class="navStats">
        <div>
          <span>Arena tier:</span>
          <span>{{ characterInformation.tier || '-' }}</span>
        </div>
        <div>
          <span>Wager left:</span>
          <span>{{ formattedWager || '-' }}</span>
        </div>
      </div>
    </nav>
    <div class="bottom">
      <div class="characterWrapper">
        <div class="elementWrapper">
          <img :src="getCharacterElementSrc" alt="element" />
        </div>
        <div class="characterImageWrapper">
          <pvp-character :characterId="currentCharacterId" />
        </div>
        <div v-if="characterInformation" class="info">
          <h1 class="characterName">{{ characterInformation.name }}</h1>
          <div class="infoDetails">
            <span>Level: {{ characterInformation.level }}</span>
            <pvp-separator vertical class="separator" />
            <span>Rank: {{ characterInformation.rank }}</span>
          </div>
        </div>
        <div class="weapons" :class="{'hasShield': activeShieldWithInformation.shieldId}">
          <pvp-weapon
            v-if="activeWeaponWithInformation.weaponId"
            :weapon="activeWeaponWithInformation.information"
            :weaponId="activeWeaponWithInformation.weaponId"
            :hasInfoPopover="false"
          />
          <pvp-shield
            v-if="activeShieldWithInformation.shieldId"
            :shield="activeShieldWithInformation.information"
            :shieldId="activeShieldWithInformation.shieldId"
            :hasInfoPopover="false"
          />
        </div>
      </div>
      <div class="middleButtons">
        <div class="middleButtonsStatus">
          <div v-if="this.loading || isCharacterInDuelQueue">
            <img class="spinner" src="../../assets/loadingSpinner.svg" />
          </div>
          <p v-if="isInMatch && !isCharacterInDuelQueue && !this.loading && this.decisionTimeLeft">
            <span>You have</span>
            <span>{{ this.decisionTimeLeft }}</span>
            <span>to accept the duel</span>
          </p>
          <span v-else-if="this.decisionTimeLeft === 0 && !this.loading && isCharacterInDuelQueue">Duel has expired.</span>
        </div>
        <div class="middleMatchProgressButtons">
          <pvp-button v-if="isCharacterInDuelQueue" buttonText="IN-PROGRESS" :disabled="true"/>
          <div v-else class="matchButtonsWrapper">
            <pvp-button v-if="!isInMatch" @click="findMatch" :disabled="loading" buttonText="FIND MATCH" />
            <pvp-button v-else
            @click="prepareDuel" :disabled="loading || !decisionTimeLeft || isCharacterInDuelQueue" :duelButton="true" buttonText="DUEL" />
          </div>
        </div>
        <div class="rerollButtonWrapper">
          <pvp-button
            @click="reRollOpponent" :disabled="loading || !isInMatch || isCharacterInDuelQueue"
            buttonText="Re-roll Opponent"
            :buttonsubText="'$SKILL: ' + formattedReRollCost"
            :secondary="true"
          />
        </div>
        <div class="leaveArenaButtonWrapper">
          <pvp-button
            @click="leaveArena"
            :disabled="loading || isCharacterInDuelQueue"
            buttonText="Leave Arena"
            :secondary="true"
          />
        </div>
      </div>
      <div class="characterWrapper">
        <div class="elementWrapper">
          <img v-if="opponentInformation.id" :src="getOpponentElementSrc" alt="opponent element" />
        </div>
        <div v-if="opponentInformation.id" class="characterImageWrapper">
          <pvp-character :characterId="opponentInformation.id" />
        </div>
        <div v-if="opponentInformation.id" class="info">
          <h1 class="characterName">{{ opponentInformation.name }}</h1>
          <div class="infoDetails">
            <span>Level: {{ opponentInformation.level }}</span>
            <pvp-separator vertical class="separator" />
            <span>Rank: {{ opponentInformation.rank }}</span>
          </div>
        </div>
        <span v-else class="findMatchMessage">Press FIND MATCH to find an opponent!</span>
        <div class="weapons" :class="{'hasShield': activeShieldWithInformation.shieldId}">
          <pvp-weapon
            v-if="opponentActiveWeaponWithInformation.weaponId"
            :weapon="opponentActiveWeaponWithInformation.information"
            :weaponId="opponentActiveWeaponWithInformation.weaponId"
            :hasInfoPopover="false"
          />
          <pvp-shield
            v-if="opponentActiveShieldWithInformation.shieldId"
            :shield="opponentActiveShieldWithInformation.information"
            :shieldId="opponentActiveShieldWithInformation.shieldId"
            :hasInfoPopover="false"
          />
        </div>
      </div>
    </div>
    <!-- TODO: Get rank variation from contract -->
    <pvp-duel-modal
      v-if="duelResult.result"
      :result="duelResult.result"
      :attackerRoll="duelResult.attackerRoll"
      :defenderRoll="duelResult.defenderRoll"
      :skillEarned="duelResult.skillDifference"
      :rankVariation="duelResult.result === 'win' ? '+5' : '-3'"
      :userCurrentRank="duelResult.rankDifference"
      @close-modal="handleCloseModal"
    />
  </div>
</template>

<script>
import BN from 'bignumber.js';
import { mapState } from 'vuex';
import PvPWeapon from './PvPWeapon.vue';
import PvPShield from './PvPShield.vue';
import PvPSeparator from './PvPSeparator.vue';
import PvPCharacter from './PvPCharacter.vue';
import PvPButton from './PvPButton.vue';
import fireIcon from '../../assets/elements/fire.png';
import waterIcon from '../../assets/elements/water.png';
import earthIcon from '../../assets/elements/earth.png';
import lightningIcon from '../../assets/elements/lightning.png';
import PvPDuelModal from './PvPDuelModal.vue';
import { duelResultFromContract as formatDuelResult } from '../../contract-models';

export default {
  inject: ['web3'],

  components: {
    'pvp-weapon': PvPWeapon,
    'pvp-shield': PvPShield,
    'pvp-character': PvPCharacter,
    'pvp-separator': PvPSeparator,
    'pvp-button': PvPButton,
    'pvp-duel-modal': PvPDuelModal
  },

  props: {
    characterInformation: {
      default: {
        tier: null,
        name: '',
        level: null,
        power: null,
        rank: null,
        element: null
      }
    },
    activeWeaponWithInformation: {
      default: {
        weaponId: null,
        information: {}
      }
    },
    activeShieldWithInformation: {
      default: {
        shieldId: null,
        information: {}
      }
    },
    opponentInformation: {
      default: {
        if: null,
        element: '',
        name: '',
        level: null,
        rank: null
      }
    },
    opponentActiveWeaponWithInformation: {
      default: {
        weaponId: null,
        information: {}
      }
    },
    opponentActiveShieldWithInformation: {
      default: {
        shieldId: null,
        information: {}
      }
    },
  },

  data() {
    return {
      loading: true,
      isInMatch: false,
      decisionTimeLeft: 0,
      wager: null,
      duelCost: null,
      reRollCost: null,
      match: {
        attackerID: null,
        defenderID: null,
        createdAt: null,
      },
      duelQueue: [],
      isCharacterInDuelQueue: false,
      duelResult: {
        attackerRoll: null,
        defenderRoll: null,
        skillDifference: null,
        rankDifference: null,
        result: ''
      }
    };
  },

  computed: {
    ...mapState(['contracts', 'currentCharacterId', 'defaultAccount']),

    formattedWager() {
      return new BN(this.wager).div(new BN(10).pow(18)).toFixed(2);
    },

    formattedDuelCost() {
      return new BN(this.duelCost).div(new BN(10).pow(18)).toFixed(2);
    },

    formattedReRollCost() {
      return new BN(this.reRollCost).div(new BN(10).pow(18)).toFixed(2);
    },

    getCharacterElementSrc() {
      if (this.characterInformation.element === 'Fire') {
        return fireIcon;
      }
      if (this.characterInformation.element === 'Water') {
        return waterIcon;
      }
      if (this.characterInformation.element === 'Earth') {
        return earthIcon;
      }
      return lightningIcon;
    },

    getOpponentElementSrc() {
      if (this.opponentInformation.element === 'fire') {
        return fireIcon;
      }
      if (this.opponentInformation.element === 'water') {
        return waterIcon;
      }
      if (this.opponentInformation.element === 'earth') {
        return earthIcon;
      }
      return lightningIcon;
    },
  },

  methods: {
    handleErrorMessage(value, errorMessage, returnedMessage) {
      if (value.includes(`reverted with reason string '${errorMessage}'`)) {
        return this.$dialog.notify.error(returnedMessage);
      }
      return 'There has been an error. Try again.';
    },

    async leaveArena() {
      this.loading = true;

      try {
        await this.contracts().PvpArena.methods.withdrawFromArena(this.currentCharacterId).send({ from: this.defaultAccount });

        this.$emit('leaveArena');
      } catch (err) {
        console.log('leave arena error: ', err.message);

        this.handleErrorMessage(err.message, 'Char not in arena', 'The character is not in the arena');
        this.handleErrorMessage(err.message, 'Defender duel in process', 'Duel already in process');
      }

      this.loading = false;
    },

    async findMatch() {
      if (!(await this.contracts().PvpArena.methods.isCharacterNotUnderAttack(this.currentCharacterId).call())) {
        alert('You are currently under attack. Please wait a moment.');
        return;
      }

      this.loading = true;

      try {
        await this.contracts().PvpArena.methods.findOpponent(this.currentCharacterId).send({ from: this.defaultAccount });
      } catch (err) {
        console.log('find match error: ', err.message);

        this.handleErrorMessage(err.message, 'No enemy found', 'No opponent has been found. Try again.');
        this.handleErrorMessage(err.message, 'Already in match', 'An opponent has already been requested.');
        this.handleErrorMessage(err.message, 'No enemy in tier', 'No opponents available in this tier.');
        this.handleErrorMessage(err.message, 'Char dueling', 'The character is already in a duel queue.');
        this.handleErrorMessage(err.message, 'Char not in arena', 'The character is not in the arena.');

        this.loading = false;
        return;
      }

      this.match = await this.contracts().PvpArena.methods.matchByFinder(this.currentCharacterId).call();

      this.loading = false;
    },

    async reRollOpponent() {
      if (!(await this.contracts().PvpArena.methods.isCharacterNotUnderAttack(this.currentCharacterId).call())) {
        alert('You are currently under attack. Please wait a moment.');
        return;
      }

      this.loading = true;

      try {
        await this.contracts().SkillToken.methods
          .approve(this.contracts().PvpArena.options.address, `${this.reRollCost.toFixed(0)}`).send({ from: this.defaultAccount });

        await this.contracts().PvpArena.methods.reRollOpponent(this.currentCharacterId).send({ from: this.defaultAccount });
      } catch (err) {
        console.log('reroll opponent error: ', err.message);

        this.handleErrorMessage(err.message, 'No enemy found', 'No opponent has been found. Try again.');
        this.handleErrorMessage(err.message, 'Not in match', 'The character is not in a match. Try again.');
        this.handleErrorMessage(err.message, 'No enemy in tier', 'No opponents available in this tier.');
        this.handleErrorMessage(err.message, 'Char dueling', 'The character is already in a duel queue.');

        this.loading = false;

        return;
      }

      this.match = await this.contracts().PvpArena.methods.matchByFinder(this.currentCharacterId).call();

      this.loading = false;
    },

    async listenForDuel(contracts) {
      const currentBlock = await this.web3.eth.getBlockNumber();

      const subscription = this.web3.eth.subscribe('newBlockHeaders', async () => {
        const duelFinishedResult = await contracts.PvpArena.getPastEvents('DuelFinished', {
          filter: { attacker: this.currentCharacterId },
          toBlock: 'latest',
          fromBlock: currentBlock
        });

        if (duelFinishedResult.length) {
          const formattedResult = formatDuelResult(duelFinishedResult[duelFinishedResult.length - 1].returnValues);

          this.duelResult.result = formattedResult.attackerWon ? 'win' : 'lose';
          this.duelResult.attackerRoll = formattedResult.attackerRoll;
          this.duelResult.defenderRoll = formattedResult.defenderRoll;
          this.duelResult.skillDifference = formattedResult.attackerWon ?
            +this.formattedDuelCost * 0.7 :
            this.formattedDuelCost;
          // TODO: Make this prettier
          this.duelResult.rankDifference = formattedResult.attackerWon ?
            +this.characterInformation.rank + 5 :
            +this.characterInformation.rank - 3 <= 0 ?
              0 :
              +this.characterInformation.rank - 3;

          subscription.unsubscribe((error, result) => {
            if (!error) {
              console.log(result);
            } else {
              console.log(error);
            }
          });
        }
      });
    },

    async prepareDuel() {
      this.loading = true;

      try {
        await this.listenForDuel(this.contracts());

        await this.contracts().PvpArena.methods.prepareDuel(this.currentCharacterId).send({from: this.defaultAccount});
      } catch (err) {
        console.log('prepare perform duel error: ', err.message);

        this.handleErrorMessage(err.message, 'Decision time expired', 'Decision time expired.');
        this.handleErrorMessage(err.message, 'Char in duel queue', 'The character is already waiting for an opponent.');
        this.handleErrorMessage(err.message, 'Not in match', 'The character is not in a duel. Try again.');

        this.loading = false;

        return;
      }

      this.duelQueue = await this.contracts().PvpArena.methods.getDuelQueue().call({from: this.defaultAccount});

      this.isCharacterInDuelQueue = true;

      this.loading = false;
    },

    clearDuelResult() {
      this.duelResult = {
        attackerRoll: null,
        defenderRoll: null,
        skillDifference: null,
        rankDifference: null,
        result: ''
      };
    },

    async handleCloseModal() {
      this.clearDuelResult();
      this.decisionTimeLeft = 0;

      this.isInMatch = false;

      this.match = {
        attackerID: null,
        defenderID: null,
        createdAt: null,
      };

      this.isCharacterInDuelQueue = false;

      this.wager = (await this.contracts().PvpArena.methods.fighterByCharacter(this.currentCharacterId).call({ from: this.defaultAccount })).wager;

      if (this.wager < this.duelCost) {
        this.$emit('kickCharacterFromArena');
      }

      this.$emit('updateRank');
    }
  },

  async created() {
    this.loading = true;

    this.isInMatch = (await this.contracts().PvpArena.methods.matchByFinder(this.currentCharacterId).call()).createdAt !== '0';

    this.duelQueue = await this.contracts().PvpArena.methods.getDuelQueue().call({from: this.defaultAccount});

    if (this.duelQueue.includes(`${this.currentCharacterId}`)) {
      this.isCharacterInDuelQueue = true;

      await this.listenForDuel(this.contracts());
    }

    this.decisionSeconds = await this.contracts().PvpArena.methods.decisionSeconds().call();

    this.wager = (await this.contracts().PvpArena.methods.fighterByCharacter(this.currentCharacterId).call({ from: this.defaultAccount })).wager;

    this.duelCost = await this.contracts().PvpArena.methods.getDuelCost(this.currentCharacterId).call({ from: this.defaultAccount });

    this.reRollCost = this.duelCost * ((await this.contracts().PvpArena.methods.reRollFeePercent().call({ from: this.defaultAccount })) / 100);

    if (this.isInMatch) {
      const timeNow = Math.floor((new Date()).getTime() / 1000);

      this.match = await this.contracts().PvpArena.methods.matchByFinder(this.currentCharacterId).call();

      this.decisionTimeLeft = (this.decisionSeconds - (timeNow - this.match.createdAt), 0);

      // Note: This gives a 400 seconds decisionTimeLeft locally. Test if it's ok on testnet.
      this.timer = setInterval(() => {
        if (this.isInMatch && !this.isCharacterInDuelQueue) {
          const timeNow = Math.floor((new Date()).getTime() / 1000);

          this.decisionTimeLeft = Math.max(this.decisionSeconds - (timeNow - this.match.createdAt), 0);
        }
      }, 1000);
    } else {
      this.match = {
        attackerID: null,
        defenderID: null,
        createdAt: null,
      };

      this.decisionTimeLeft = 0;
    }

    this.duelQueue = await this.contracts().PvpArena.methods.getDuelQueue().call({from: this.defaultAccount});

    this.loading = false;
  },

  watch: {
    async match(value) {
      this.loading = true;

      if (value.defenderID) {
        this.$emit('updateOpponentInformation', value.defenderID);

        this.isInMatch = true;

        const timeNow = Math.floor((new Date()).getTime() / 1000);

        this.decisionTimeLeft = (this.decisionSeconds - (timeNow - this.match.createdAt), 0);

        // Note: This gives a 400 seconds decisionTimeLeft locally. Test if it's ok on testnet.
        this.timer = setInterval(() => {
          if (this.isInMatch && !this.isCharacterInDuelQueue) {
            const timeNow = Math.floor((new Date()).getTime() / 1000);

            this.decisionTimeLeft = Math.max(this.decisionSeconds - (timeNow - this.match.createdAt), 0);
          }
        }, 1000);
      } else {
        this.$emit('clearOpponentInformation');
      }
      this.loading = false;
    },
  }
};
</script>

<style scoped lang="scss">
.wrapper {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  margin-top: 1rem;
}
span, p, li, button {
  font-family: 'Roboto';
}
  nav {
    display: flex;
    width: 100%;
    justify-content: space-between;
    margin-bottom: 4rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid #363636;
    .navTitle {
      color: #cec198;
      font-size: 1.25rem;
      font-family: 'Trajan';
    }
    .navStats {
      display: flex;
      div:nth-of-type(2) {
        margin-left: 1.25rem;
        margin-right: 1.25rem;
      }
      div {
        display: flex;
        align-items: flex-end;
        font-size: 0.875rem;
        line-height: 1.25rem;
        span:first-of-type {
          margin-right: 0.25rem;
          color: #cec198;
        }
        span:last-of-type {
          color: #ffffff;
        }
      }
    }
  }
.bottom {
  display: flex;
  flex-direction: row;
  width: 100%;
  justify-content: center;
  .elementWrapper {
    position: absolute;
    display: flex;
    height: 2.5rem;
    width: 2.5rem;
    top: -5.35%;
    left: 0;
    right: 0;
    padding: 0.4rem;
    transform: rotate(45deg);
    border: 1px solid #edcd90;
    margin-right: auto;
    margin-left: auto;
    background-color: #000000;
    img {
      transform: rotate(-45deg);
    }
  }
}
.characterWrapper,
.middleButtons {
  display: flex;
  height: 25rem;
  justify-content: flex-end;
  align-items: center;
}
.characterWrapper {
  position: relative;
  flex-direction: column;
  width: 35%;
  background-color: #000;
  border: 1px solid #cec198;
  @media screen and (min-width: 1240px) {
    width: 30%;
  }
  @media screen and (min-width: 1440px) {
    width: 25%;
  }
  @media screen and (min-width: 1680px) {
    width: 20%;
  }
  @media screen and (min-width: 2560px) {
    width: 15%;
  }
  .findMatchMessage {
    display: flex;
    width: 75%;
    margin: auto;
    color: gray;
    font-family: 'Trajan';
    font-weight: 200;
    text-align: center;
    span {
      color: #EDCD90;
      font-family: 'Trajan';
    }
  }
  .characterImageWrapper {
    display: flex;
    margin-right: auto;
    margin-left: auto;
    width: 55%;
    height: 55%;
    margin-bottom: 7rem;
  }
  .info {
    position: absolute;
    bottom: 0;
    display: flex;
    width: 100%;
    flex-direction: column;
    align-items: center;
    color: #ffffff;
    margin-bottom: 2.5rem;
    .characterName {
      margin-bottom: 0.3rem;
      color: #EDCD90;
      font-size: 1.25rem;
      line-height: 1.75rem;
      font-family: 'Trajan';
    }
    .infoDetails {
      height: 1.25rem;
      display: flex;
      align-items: center;
      vertical-align: middle;
      font-size: 0.875rem;
      line-height: 1.25rem;
      .separator {
        margin-right: 1.25rem;
        margin-left: 1.25rem;
      }
    }
  }
  .weapons {
    position: absolute;
    bottom: -12%;
    display: flex;
    left: 0;
    justify-content: center;
    right: 0;
    margin-right: auto;
    margin-left: auto;
    &.hasShield{
      div:first-of-type {
        margin-right: 1rem;
      }
    }
  }
}
.middleButtons {
  flex-direction: column;
  margin: 0 3rem;
  width: 13rem;
  .spinner {
    animation: spin 1s linear infinite;
    @keyframes spin {
      from {
        transform: rotate(0deg);
      }
      to {
        transform: rotate(360deg);
      }
    }
  }
  .middleButtonsStatus {
    width: 100%;
    display: flex;
    height: 7rem;
    flex-direction: column;
    justify-content: center;
    vertical-align: middle;
    align-items: center;
    text-align: center;
    margin-bottom: 1rem;

    p {
      display: flex;
      flex-direction: column;
    }
    span:first-of-type, span:last-of-type {
      font-size: .75rem;
      color: #cec198;
    }
    span:nth-of-type(2) {
      font-size: 2.25rem;
      color: white;
      margin: 0;
    }
  }
  .middleMatchProgressButtons {
    width: 100%;
    height: 5.5rem;
    button {
      height: 100%;
    }
  }
  .matchButtonsWrapper {
    width: 100%;
    button {
      height: 5.5rem;
    }
  }
  .rerollButtonWrapper {
    width: 100%;
    height: 5rem;
    margin: 1.5rem 0;
  }
  .leaveArenaButtonWrapper {
    width: 100%;
  }
  @media screen and (min-width: 1280px) {
    margin: 0 5rem;
  }
}
</style>
