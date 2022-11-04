//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract HarmoniaDAO_V1_Core{
    //Variable Declarations
    string public Version = "V1";
    address public Treasury = address(0);
    address public TreasurySetter;
    bool public InitialTreasurySet = false;

    //Mapping, structs and other declarations
    
    Proposal[] public Proposals;

    struct Proposal{
        uint256 ProposalID;
        uint8 ProposalType; //Type 0 is simple ether and asset sends, Type 1 are Proxy Proposals for external governance, Type 2 are Eros Prosposals
        uint256 ProposalVotingLenght;
        uint256 RequestedEtherAmount; //Optional, can be zero
        uint256 RequestedAssetAmount; //Optional, can be zero
        uint8 RequestedAssetID;
        ProxyProposalArguments ProxyArgs;
        bool Executed; //Can only be executed once, when finished, proposal exist only as archive
    }

    struct ProxyProposalArguments{
        uint256 UnsignedInt1;
        uint256 UnsignedInt2;
        uint256 UnsignedInt3; 
        address Address1;
        address Address2;
        address Address3;
        bool Bool1;
        bool Bool2;
        bool Bool3;
    }



    event FallbackToTreasury(uint256 amount);
    event NewTreasurySet(address NewTreasury);


    constructor(){
        TreasurySetter = msg.sender;
    }

    //Public state-modifing functions


    //Public view functions




    //Internal Executioning

    function RegisterTreasuryAsset(address tokenAddress, uint8 slot, uint256 ProposalID) internal returns(bool success){

        TreasuryV1(treasury).RegisterAsset(tokenAddress, slot);
    }

    function VerifyProposalAuthenticity(uint256 ProposalID, uint8 ExecutionType) internal returns(bool success){
        require(Proposals[ProposalID].ProposalType == ExecutionType);
        if(Proposals[ProposalID].RequestedAssetID != address(0)){
            require(Proposals[ProposalID].RequestedAssetID); //Require asset is registered
        }
    }


    
    //One Time Functions
    function SetInitialTreasury(address TreasuryAddress) external{
        require(msg.sender == TreasurySetter);
        require(InitialTreasurySet == false);

        Treasury = TreasuryAddress;
        TreasurySetter = address(0); //Once the reasury address has been set for the first time, it can only be set again via proposal 
        InitialTreasurySet = true;

        emit NewTreasurySet(TreasuryAddress);
    }

    


    receive() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(Treasury).transfer(address(this).balance);
    }

    fallback() external payable{
        emit FallbackToTreasury(address(this).balance);
        payable(Treasury).transfer(address(this).balance);
    }


}
//Only for the first treasury, if the DAO contract is not updated but the treasury is in the future, only Eros proposals will be able to access it due to their flexibility
interface TreasuryV1{//Only for the first treasury, if the DAO contract is not updated but the treasury is in the future,
//Public State Modifing Functions
    function ReceiveRegisteredAsset(uint8 AssetID, uint amount) external;
    function UserAssetClaim(uint256 CLDamount) public returns(bool success);
    function AssetClaim(uint256 CLDamount, address From, address payable To) public returns(bool success);
//OnlyDAO or OnlyEros State Modifing Functions
    function TransferETH(uint256 amount, address payable receiver) external;
    function TransferERC20(uint8 AssetID, uint256 amount, address receiver) external;
    function RegisterAsset(address tokenAddress, uint8 slot) external;
    function ChangeRegisteredAssetLimit(uint8 NewLimit) external;
//Public View Functions
    function IsRegistered(address TokenAddress) public view;
    function GetBackingValueEther(uint256 CLDamount) public view returns(uint256 EtherBacking);
}