// forked from https://github.com/IndexCoop/index-coop-smart-contracts/blob/master/contracts/lib/MutualConsent.sol

pragma solidity 0.8.9;

/**
 * @title MutualConsent
 * @author Set Protocol
 *
 * The MutualConsent contract contains a modifier for handling mutual consents between two parties
 */
abstract contract MutualConsent {
    /* ============ State Variables ============ */

    uint256 constant MAX_DATA_LENGTH = 164;

    // Mapping of upgradable units and if consent has been initialized by other party
    mapping(bytes32 => address) public mutualConsents;

    error Unauthorized();
    error InvalidConsent();
    error NotUserConsent();

    // causes revert when the msg.data passed in has more data (ie arguments) than the largest known fn signature
    error UnsupportedMutualConsentFunction();

    /* ============ Events ============ */

    event MutualConsentRegistered(bytes32 _consentHash);
    event MutualConsentRevoked(address indexed user, bytes32 _toRevoke);

    /* ============ Modifiers ============ */

    /**
     * @notice - allows a function to be called if only two specific stakeholders signoff on the tx data
     *         - signers can be anyone. only two signers per contract or dynamic signers per tx.
     */
    modifier mutualConsent(address _signerOne, address _signerTwo) {
        if (_mutualConsent(_signerOne, _signerTwo)) {
            // Run whatever code needed 2/2 consent
            _;
        }
    }

    // TODO: test every mutual consent function
    // TODO: add natspec for
    // TODO: add note for MAX_DATA_LENGTH
    function revokeConsent(bytes memory _reconstrucedMsgData) public {
        if (_reconstrucedMsgData.length > MAX_DATA_LENGTH) {
            revert UnsupportedMutualConsentFunction();
        } // TODO: test me
        bytes32 hashToDelete = keccak256(
            abi.encodePacked(_reconstrucedMsgData, msg.sender)
        );

        if (mutualConsents[hashToDelete] == address(0)) {
            revert InvalidConsent();
        }
        if (mutualConsents[hashToDelete] != msg.sender) {
            revert NotUserConsent();
        } // note: cannot test, as no way to know what data (+msg.sender) would cause hash collision

        delete mutualConsents[hashToDelete];

        emit MutualConsentRevoked(msg.sender, hashToDelete);
    }

    /* ============ Internal Functions ============ */

    function _mutualConsent(address _signerOne, address _signerTwo)
        internal
        returns (bool)
    {
        if (msg.sender != _signerOne && msg.sender != _signerTwo) {
            revert Unauthorized();
        }

        address nonCaller = _getNonCaller(_signerOne, _signerTwo);

        // The consent hash is defined by the hash of the transaction call data and sender of msg,
        // which uniquely identifies the function, arguments, and sender.
        bytes32 expectedHash = keccak256(abi.encodePacked(msg.data, nonCaller));

        if (mutualConsents[expectedHash] == address(0)) {
            bytes32 newHash = keccak256(abi.encodePacked(msg.data, msg.sender));

            mutualConsents[newHash] = msg.sender;

            emit MutualConsentRegistered(newHash);

            return false;
        }

        delete mutualConsents[expectedHash];

        return true;
    }

    function _getNonCaller(address _signerOne, address _signerTwo)
        internal
        view
        returns (address)
    {
        return msg.sender == _signerOne ? _signerTwo : _signerOne;
    }
}
