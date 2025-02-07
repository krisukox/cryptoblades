import axios from 'axios';
import BigNumber from 'bignumber.js';
import Web3 from 'web3';
import config from '../../app-config.json';

BigNumber.config({ ROUNDING_MODE: BigNumber.ROUND_DOWN });
BigNumber.config({ EXPONENTIAL_AT: 100 });

const web3 = new Web3(Web3.givenProvider || process.env.VUE_APP_WEB3_FALLBACK_PROVIDER);

interface Config {
  environments: Record<string, Chain>;
}

interface Chain {
  chains: Record<string, Record<string, any>>;
}

// executes when network is changed in MetaMask
(window as any).ethereum.on('chainChanged', (chainIdHex: string) => {
  const chainId = parseInt(chainIdHex, 16);
  const env = window.location.href.startsWith('https://test') ? 'test' : 'production';
  const chains = (config as Config).environments[env].chains;

  for (const [chainName, values] of Object.entries(chains)){
    if(+values.VUE_APP_NETWORK_ID === chainId){
      localStorage.setItem('currentChain', chainName);
    }
  }
  window.location.reload();
});

export const apiUrl = (url: string) => `${process.env.VUE_APP_API_URL || 'https://api.cryptoblades.io'}/${url}`;

export const getCurrentGasPrices = async () => {
  const response = await axios.get('https://www.gasnow.org/api/v3/gas/price');
  return {
    low: response.data.data.slow / 1e9,
    medium: response.data.data.standard / 1e9,
    high: response.data.data.fast / 1e9
  };
};

export const toBN = (value: string|number): BigNumber => {
  const valueString = typeof value === 'string' ? value : String(value);

  return new BigNumber(valueString);
};

export const bnMinimum = (...values: string[]): BigNumber => {
  return BigNumber.minimum(...values);
};

export const fromWeiEther = (value: string|BigNumber): string => {
  return new BigNumber(value).div('1000000000000000000').toFixed();
};

export const gasUsedToBnb = (gasUsed: number, gasPrice: string): string => {
  const gasCost = gasUsed * Number(gasPrice);

  const bnbGasCost =  Web3.utils.fromWei(gasCost.toString()).toString();

  return  bnbGasCost;
};

export const copyNftUrl = (id: number | string, type?: string): void => {
  const path = `/#/nft-display/${type}/${id}`;
  const dummy = document.createElement('input'),
    text = window.location.origin + path;
  document.body.appendChild(dummy);
  dummy.value = text;
  dummy.select();
  document.execCommand('copy');
  document.body.removeChild(dummy);
};

export const addTokenToMetamask = async (address: string, symbol: string): Promise<void> => {
  try {
    await (web3.currentProvider as any).request({
      method: 'wallet_watchAsset',
      params: {
        type: 'ERC20',
        options: {
          address,
          symbol,
          decimals: 18
        },
      },
    });
  } catch (error) {
    console.error(error);
  }
};
