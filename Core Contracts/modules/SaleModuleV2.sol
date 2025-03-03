//SPDX-License-Identifier:UNLICENSE
/* This contract is able to be replaced by the Winslow Core, and can also continue to be used 
if a new Winslow Core is deployed by changing DAO addresses
This contract provides a factory and sale contract for the Winslow Core to initiate sales of CLD from the treasury*/
pragma solidity ^0.8.17;

contract SaleFactoryV2 {
    string public Version = "V1";
    address public DAO;
    uint256 public FoundationFee; //Defaults to these values, these values must be changed by a proposal and cannot be included while creating a sale
    uint256 public RetractFee; //^
    uint256 public MinimumDeposit; //^
    uint256 public DefaultSaleLength; //^
    uint256 public MaximumSalePercentage; //^The maximum percentage of the supply that can be sold at once, to avoid flooding markets/heavy inflation, in Basis Points

    constructor(address _DAOaddr){
        DAO = _DAOaddr;
        //Set default values for variables
    }

    //Events
    event NewSaleCreated(uint256 SaleID, uint256 SaleAmount, address NewSaleContract);
    event NewFoundationFee(uint256 NewFeePercentBP);
    event NewDepositRetractFee(uint256 NewFeePercentBP);
    event NewMinimumDeposit(uint256 NewMinDeposit);
    event NewDefaultSaleLength(uint256 NewSaleLen);
    event NewMaxSalePercent(uint256 NewMax);
    event NewDAOAddress(address NewDAO);

    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    }

    function CreateNewSale(uint256 SaleID, uint256 CLDtoSell) external OnlyDAO returns(address _NewSaleAddress){
        uint256 TreasuryCLDBalance = ERC20(Core(DAO).CLDAddress()).balanceOf(Core(DAO).TreasuryContract());
        require(TreasuryCLDBalance >= CLDtoSell && CLDtoSell <= (((ERC20(Core(DAO).CLDAddress()).totalSupply() - TreasuryCLDBalance) * MaximumSalePercentage) / 10000)); //TODO: Ensure the math here is right
        address NewSaleAddress = address(new SaleV2(DAO, SaleID, CLDtoSell, DefaultSaleLength, FoundationFee, RetractFee, MinimumDeposit));
        
        emit NewSaleCreated(SaleID, CLDtoSell, NewSaleAddress);
        return(NewSaleAddress);
    }

    //TODO: Be able to change variables using dao proposal

    function ChangeFoundationFee(uint256 NewFee) external OnlyDAO returns(bool success){
        require(NewFee <= 10000);
        FoundationFee = NewFee;

        emit NewFoundationFee(NewFee);
        return(success);
    }

    function ChangeRetractFee(uint256 NewRetractFee) external OnlyDAO returns(bool success){
        require(NewRetractFee <= 10000);
        RetractFee = NewRetractFee;

        emit NewDepositRetractFee(NewRetractFee);
        return(success);
    }

    function ChangeMinimumDeposit(uint256 NewMinDeposit) external OnlyDAO returns(bool success){
        require(NewMinDeposit > 0); //TODO: Find a good minimum where contract is extremely unlikely to have issues in division
        MinimumDeposit = NewMinDeposit;

        emit NewMinimumDeposit(NewMinDeposit);
        return(success);
    }

    function ChangeDefaultSaleLength(uint256 NewLength) external OnlyDAO returns(bool success){
        require(NewLength >= 259200 && NewLength <= 1209600); 
        DefaultSaleLength = NewLength;

        emit NewDefaultSaleLength(NewLength);
        return(success);
    }

    function ChangeMaxSalePercent(uint256 NewMaxPercent) external OnlyDAO returns(bool success){
        require(NewMaxPercent <= 10000);
        MaximumSalePercentage = NewMaxPercent;

        emit NewMaxSalePercent(NewMaxPercent);
        return(success);
    }

    function ChangeDAO(address newAddr) external OnlyDAO returns(bool success){
        require(DAO != newAddr, "VotingSystemV1.ChangeDAO: New DAO address can't be the same as the old one");
        require(address(newAddr) != address(0), "VotingSystemV1.ChangeDAO: New DAO can't be the zero address");
        DAO = newAddr;    

        emit NewDAOAddress(newAddr);
        return(success);
    }

}

contract SaleV2 {
    //  Variable, struct, mapping and other Declarations
    //  Core
    address public DAO;
    address public CLD;
    uint256 public SaleIdentifier; //This iteration of all CLD sales conducted
    uint256 public StartTime; //Unix Time
    uint256 public EndTime;   //Unix Time
    uint256 public CLDToBeSold; //Total Amount of CLD being offered for sale by the DAO
    //  Fees in basis points, chosen by proposer/al on deploy, so can be 0
    uint256 public MinimumDeposit; //Minimum Amount of Ether to be deposited when calling the deposit function
    uint256 public DAOFoundationFee; //Fee that goes directly to the foundation for further development
    uint256 public RetractFee; //Fee that is charged when a user removes their ether from the pool, to count as totaletherpool
    // Details
    uint256 public TotalEtherPool; //Defines the total Amount of ether deposited by participators
    uint256 public TotalRetractionFeesAccrued; //Total Amount of ether received from retraction fees
    bool public ProceedsNotTransfered = true; //Defaulted to true so that the if statement costs 0 gas after transfered for the first time

    enum SaleStatuses{ 
        Uncommenced, //Before the sale, allowing users to view the Amount of CLD that will sold and additional information
        Ongoing,     //While the sale is active, allowing users to deposit or withdraw ETC from the pool 
        Complete     //After the sale is complete, allowing users to withdraw their CLD in which they purchased
    }

    struct Participant{ 
        bool Participated;
        bool CLDclaimed;
        uint256 EtherDeposited;
        uint256 CLDWithdrawn;
    }

    modifier OnlyDAO{ 
        require(msg.sender == address(DAO), 'This can only be done by the DAO');
        _;
    } 

    event EtherDeposited(uint256 Amount, address User);
    event EtherWithdrawn(uint256 Amount, uint256 Fee, address User);
    event CLDclaimed(uint256 Amount, address User);
    event ProceedsTransfered(uint256 ToTreasury, uint256 ToFoundation);
    
    //Mapping for participants
    mapping(address => Participant) public ParticipantDetails; 
    //List of participants for front-end ranking
    address[] public ParticipantList; 

    constructor(address _DAO, uint256 SaleID, uint256 CLDtoSell, uint256 SaleLength, uint256 FoundationFee, uint256 RetractionFee, uint256 MinDeposit){
        require(SaleLength >= 259200 && SaleLength <= 1209600);
        DAO = _DAO;
        SaleIdentifier = SaleID;
        CLD = Core(DAO).CLDAddress();
        CLDToBeSold = CLDtoSell; //Make sure CLD is transfered to contract by treasury, additional CLD sent to the sale contract will be lost
        StartTime = block.timestamp + 43200;
        EndTime = StartTime + SaleLength;
        DAOFoundationFee = FoundationFee;
        RetractFee = RetractionFee;
        MinimumDeposit = MinDeposit;
    }

    //  During Sale
    //Deposit ETC

    function DepositEther() public payable returns(bool success){
        require(SaleStatus() == SaleStatuses(1));
        require(msg.value >= MinimumDeposit); 

        if(ParticipantDetails[msg.sender].Participated = false){
            ParticipantDetails[msg.sender].Participated = true;
            ParticipantList.push(msg.sender);
        }

        ParticipantDetails[msg.sender].EtherDeposited += msg.value;
        TotalEtherPool += msg.value;
        
        emit EtherDeposited(msg.value, msg.sender);
        return(success);
    }

    function WithdrawEther(uint256 Amount) public returns(bool success){
        require(ParticipantDetails[msg.sender].Participated == true);
        require(Amount <= ParticipantDetails[msg.sender].EtherDeposited);
        require(SaleStatus() == SaleStatuses(1));

        uint256 Fee = ((Amount * RetractFee) / 10000);

        TotalRetractionFeesAccrued += Fee;
        ParticipantDetails[msg.sender].EtherDeposited -= (Amount - Fee);

        payable(msg.sender).transfer(Amount - Fee);

        emit EtherWithdrawn(Amount, Fee, msg.sender);
        return(success);
    }


    function ClaimCLD() public returns(bool success, uint256 AmountClaimed){
        require(ParticipantDetails[msg.sender].Participated == true);
        require(ParticipantDetails[msg.sender].CLDclaimed == false);
        require(SaleStatus() == SaleStatuses(2));
        ParticipantDetails[msg.sender].CLDclaimed = true;

        if(ProceedsNotTransfered){
            TransferProceeds();
        }

        uint256 CLDtoSend = ((CLDToBeSold *  ParticipantDetails[msg.sender].EtherDeposited) / TotalEtherPool);
        ParticipantDetails[msg.sender].CLDWithdrawn = CLDtoSend;

        ERC20(CLD).transfer(msg.sender, CLDtoSend);

        emit CLDclaimed(CLDtoSend, msg.sender);
        return(success, CLDtoSend);
    }


    //Internal functions

    function TransferProceeds() internal {
        ProceedsNotTransfered = false;
        uint256 ToFoundation = ((TotalEtherPool * DAOFoundationFee) / 10000); //TODO: Make sure this always returns a viable send amount aka wont break the contract
        uint256 ToTreasury = (TotalEtherPool - ToFoundation);
        (Core(DAO).TreasuryContract()).transfer(ToTreasury);
        (Core(DAO).FoundationAddress()).transfer(ToFoundation);

        emit ProceedsTransfered(ToFoundation, ToTreasury);
    }

    //DAO Only functions

    function VerifyReadyForSale() external OnlyDAO view returns(bool Ready){
        require(ERC20(CLD).balanceOf(address(this)) == CLDToBeSold);
        
        return(Ready);
    }

    //View Functions

    function SaleStatus() public view returns(SaleStatuses Status){
        if(block.timestamp < StartTime){
            return(SaleStatuses(0));
        }
        if(block.timestamp > StartTime && block.timestamp < EndTime){
            return(SaleStatuses(1));
        }
        if(block.timestamp > EndTime){
            return(SaleStatuses(2));
        }
        else{
            revert("Error on getting sale status");
        }
    }

}

interface Core {
    function TreasuryContract() external view returns(address payable TreasuryAddress);
    function FoundationAddress() external view returns(address payable Foundation);
    function CLDAddress() external view returns(address CLD);
}

interface ERC20 {
  function balanceOf(address owner) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 value) external returns (bool);
  function transfer(address to, uint256 value) external returns (bool);
  function transferFrom(address from, address to, uint256 value) external returns (bool); 
  function totalSupply() external view returns (uint256);
  function Burn(uint256 _BurnAmount) external;
}