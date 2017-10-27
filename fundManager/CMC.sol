pragma solidity 0.4.11;

import './Manager.sol'

// Interface for getting contracts from Doug
contract ContractProvider {
    function contracts(bytes32 name) returns (address addr) {}
}

// Base class for contracts that only allow the fundmanager to call them.
// Note that it inherits from DougEnabled
contract FundManagerEnabled is DougEnabled {

    // Makes it easier to check that fundmanager is the caller.
    function isFundManager() constant returns (bool) {
        if(DOUG != 0x0){
            address fm = ContractProvider(DOUG).contracts("fundmanager");
            return msg.sender == fm;
        }
        return false;
    }
}

// Permissions database
contract PermissionsDb is DougEnabled {

    mapping (address => uint8) public perms;

    // Set the permissions of an account.
    function setPermission(address addr, uint8 perm) returns (bool res) {
        if(DOUG != 0x0){
            address permC = ContractProvider(DOUG).contracts("perms");
            if (msg.sender == permC ){
                perms[addr] = perm;
                return true;
            }
            return false;
        } else {
            return false;
        }
    }

}

// Permissions
contract Permissions is FundManagerEnabled {

    // Set the permissions of an account.
    function setPermission(address addr, uint8 perm) returns (bool res) {
        if (!isFundManager()){
            return false;
        }
        address permdb = ContractProvider(DOUG).contracts("permsdb");
        if ( permdb == 0x0 ) {
            return false;
        }
        return PermissionsDb(permdb).setPermission(addr, perm);
    }

}

// The bank database
contract BankDb is DougEnabled {

    mapping (address => uint) public balances;

    function deposit(address addr) returns (bool res) {
        if(DOUG != 0x0){
            address bank = ContractProvider(DOUG).contracts("bank");
            if (msg.sender == bank ){
                balances[addr] += msg.value;
                return true;
            }
        }
        // Return if deposit cannot be made.
        msg.sender.send(msg.value);
        return false;
    }

    function withdraw(address addr, uint amount) returns (bool res) {
        if(DOUG != 0x0){
            address bank = ContractProvider(DOUG).contracts("bank");
            if (msg.sender == bank ){
                uint oldBalance = balances[addr];
                if(oldBalance >= amount){
                    msg.sender.send(amount);
                    balances[addr] = oldBalance - amount;
                    return true;
                }
            }
        }
        return false;
    }

}

// The bank
contract Bank is FundManagerEnabled {

    // Attempt to withdraw the given 'amount' of Ether from the account.
    function deposit(address userAddr) returns (bool res) {
        if (!isFundManager()){
            return false;
        }
        address bankdb = ContractProvider(DOUG).contracts("bankdb");
        if ( bankdb == 0x0 ) {
            // If the user sent money, we should return it if we can't deposit.
            msg.sender.send(msg.value);
            return false;
        }

        // Use the interface to call on the bank contract. We pass msg.value along as well.
        bool success = BankDb(bankdb).deposit.value(msg.value)(userAddr);

        // If the transaction failed, return the Ether to the caller.
        if (!success) {
            msg.sender.send(msg.value);
        }
        return success;
    }

    // Attempt to withdraw the given 'amount' of Ether from the account.
    function withdraw(address userAddr, uint amount) returns (bool res) {
        if (!isFundManager()){
            return false;
        }
        address bankdb = ContractProvider(DOUG).contracts("bankdb");
        if ( bankdb == 0x0 ) {
            return false;
        }

        // Use the interface to call on the bank contract.
        bool success = BankDb(bankdb).withdraw(userAddr, amount);

        // If the transaction succeeded, pass the Ether on to the caller.
        if (success) {
            userAddr.send(amount);
        }
        return success;
    }

}

// The fund manager
contract FundManager is DougEnabled {

    // We still want an owner.
    address owner;

    // Constructor
    function FundManager(){
        owner = msg.sender;
    }

    // Attempt to withdraw the given 'amount' of Ether from the account.
    function deposit() returns (bool res) {
        if (msg.value == 0){
            return false;
        }
        address bank = ContractProvider(DOUG).contracts("bank");
        address permsdb = ContractProvider(DOUG).contracts("permsdb");
        if ( bank == 0x0 || permsdb == 0x0 || PermissionsDb(permsdb).perms(msg.sender) < 1) {
            // If the user sent money, we should return it if we can't deposit.
            msg.sender.send(msg.value);
            return false;
        }

        // Use the interface to call on the bank contract. We pass msg.value along as well.
        bool success = Bank(bank).deposit.value(msg.value)(msg.sender);

        // If the transaction failed, return the Ether to the caller.
        if (!success) {
            msg.sender.send(msg.value);
        }
        return success;
    }

    // Attempt to withdraw the given 'amount' of Ether from the account.
    function withdraw(uint amount) returns (bool res) {
        if (amount == 0){
            return false;
        }
        address bank = ContractProvider(DOUG).contracts("bank");
        address permsdb = ContractProvider(DOUG).contracts("permsdb");
        if ( bank == 0x0 || permsdb == 0x0 || PermissionsDb(permsdb).perms(msg.sender) < 1) {
            // If the user sent money, we should return it if we can't deposit.
            msg.sender.send(msg.value);
            return false;
        }

        // Use the interface to call on the bank contract.
        bool success = Bank(bank).withdraw(msg.sender, amount);

        // If the transaction succeeded, pass the Ether on to the caller.
        if (success) {
            msg.sender.send(amount);
        }
        return success;
    }

    // Set the permissions for a given address.
    function setPermission(address addr, uint8 permLvl) returns (bool res) {
        if (msg.sender != owner){
            return false;
        }
        address perms = ContractProvider(DOUG).contracts("perms");
        if ( perms == 0x0 ) {
            return false;
        }
        return Permissions(perms).setPermission(addr,permLvl);
    }

}
