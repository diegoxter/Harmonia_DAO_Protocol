//SPDX-License-Identifier:UNLICENSE
pragma solidity ^0.8.17;


contract ErosProposal{
    address payable public  DAO = payable(0x0000000000000000000000000000000000000000);
    bool public Executed;
    uint256 RequestEther = 1 ether;
    uint256 RequestTokens = 0;
    address TokenAddress = 0x0000000000000000000000000000000000000000;

    //Additional variables can be added here
    address public ExternalContract = 0x0000000000000000000000000000000000000000;
    //Additional variables can be added here

    modifier OnlyDAO{ //This same modifier must be used on external contracts called by this contract 
        require(msg.sender == DAO);
        _;
    }


    function Execute() external OnlyDAO returns(bool success){
        Executed = true; //Updates first to avoid recursive calling
        EROSDAO(DAO).ErosProposalExecuted(address(this));

        //External or internal code to execute
        ExtCon(ExternalContract).Update("This value was updated by the DAO!");
        //External or internal code to execute

        if(address(this).balance > 0){
            DAO.transfer(address(this).balance);
        }
        return(success);
    }

    //Additional functions can go here that can only be executed by the Execute() function, therefore must be internal, public functions may present vulenrabilities to external contracts

}

interface EROSDAO{
    function CheckErosApproval(address) external view returns(bool);
    function ErosProposalExecuted(address) external; //This function in the DAO must require that the msg.sender is the same as the input
}

interface ExtCon{ //Interface name can be different, ensure 
    function ErosImplemented() external view returns(bool);
    function Update(string calldata) external;
}