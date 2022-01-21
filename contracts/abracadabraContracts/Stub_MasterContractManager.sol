// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import './Stub_BoringOwnable.sol';
import './Stub_BoringFactory.sol';

contract Stub_MasterContractManager is Stub_BoringOwnable, Stub_BoringFactory{

    mapping(address => mapping(address => bool)) public masterContractApproved;
    mapping(address => bool) public whitelistedMasterContracts;
    mapping(address => uint256) public nonces;

    bytes32 private constant DOMAIN_SEPARATOR_SIGNATURE_HASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    string private constant EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA = "\x19\x01";
    bytes32 private constant APPROVAL_SIGNATURE_HASH = 
        keccak256("SetMasterContractApproval(string warning,address user,address masterContract,bool approved,uint256 nonce)");
    bytes32 private _DOMAIN_SEPARATOR;
    uint256 private DOMAIN_SEPARATOR_CHAIN_ID;

    constructor()public{
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        _DOMAIN_SEPARATOR = _calculateDomainSeparator(DOMAIN_SEPARATOR_CHAIN_ID = chainId);
    }

    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_SIGNATURE_HASH, keccak256("BentoBox V1"), chainId, address(this)));
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId == DOMAIN_SEPARATOR_CHAIN_ID ? _DOMAIN_SEPARATOR : _calculateDomainSeparator(chainId);
    }

    function registerProtocol() public {
        masterContractOf[msg.sender] = msg.sender;
    }

    function setMasterContractApproval(address user, address masterContract, bool approved)public{
      require(masterContract != address(0), "MasterCMgr: masterC not set"); // Important for security
        masterContractApproved[masterContract][user] = approved;
    }
}