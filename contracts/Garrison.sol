pragma solidity ^0.6.2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./characters.sol";

contract Garrison is Initializable, IERC721ReceiverUpgradeable, AccessControlUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant GAME_ADMIN = keccak256("GAME_ADMIN");

    // STATE
    Characters characters;

    EnumerableSet.AddressSet private supportedTokenTypes;

    mapping(address => EnumerableSet.UintSet) userGarrison;
    mapping(uint256 => address) characterOwner;
    EnumerableSet.UintSet private allCharactersInGarrison;

    event CharacterReceived(uint256 indexed character, address indexed minter);

    function initialize(Characters _characters)
        public
        initializer
    {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        characters = _characters;
    }

    // MODIFIERS
    modifier restricted() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(GAME_ADMIN, msg.sender), "Not admin");
        _;
    }

    modifier isCharacterOwner(uint256 id) {
        require(characterOwner[id] == msg.sender);
        _;
    }

    modifier isInGarrison(uint256 id) {
        require(allCharactersInGarrison.contains(id));
        _;
    }

    // VIEWS
    function getUserCharacters() public view  returns (uint256[] memory tokens) {
        uint256 amount = balanceOf(msg.sender);
        tokens = new uint256[](amount);

        EnumerableSet.UintSet storage storedTokens = userGarrison[msg.sender];

        for (uint256 i = 0; i < amount; i++) {
            uint256 id = storedTokens.at(i);
                tokens[i] = id;
        }
    }

    function balanceOf(address user) public view returns(uint256) {
        return userGarrison[user].length();
    }

    // MUTATIVE
    function sendToGarrison(uint256 id) public {
        characterOwner[id] = msg.sender;
        userGarrison[msg.sender].add(id);
        allCharactersInGarrison.add(id);
        characters.safeTransferFrom(msg.sender, address(this), id);

        emit CharacterReceived(id, msg.sender);
    }

    function redirectToGarrison(address user, uint256 id) restricted external {
        characterOwner[id] = user;
        userGarrison[user].add(id);
        allCharactersInGarrison.add(id);

        emit CharacterReceived(id, user);
    }

    function restoreFromGarrison(uint256 id)
        public
        isCharacterOwner(id)
        isInGarrison(id)
    {
        require(characters.balanceOf(msg.sender) < characters.characterLimit(), "Receiver has too many characters");
        delete characterOwner[id];
        userGarrison[msg.sender].remove(id);
        allCharactersInGarrison.remove(id);
        characters.safeTransferFrom(address(this), msg.sender, id);
    }

    function swapWithGarrison(uint256 plazaId, uint256 garrisonId) external {
      sendToGarrison(plazaId);
      restoreFromGarrison(garrisonId);
    }

    function allowToken(IERC721 _tokenAddress) public restricted {
        supportedTokenTypes.add(address(_tokenAddress));
    }

    function disallowToken(IERC721 _tokenAddress) public restricted {
        supportedTokenTypes.remove(address(_tokenAddress));
    }

    function onERC721Received(
        address, /* operator */
        address, /* from */
        uint256 _id,
        bytes calldata /* data */
    ) external override returns (bytes4) {
        // NOTE: The contract address is always the message sender.
        address _tokenAddress = msg.sender;

        require(
            supportedTokenTypes.contains(_tokenAddress) &&
                allCharactersInGarrison.contains(_id),
            "Token ID not listed"
        );

        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }
}