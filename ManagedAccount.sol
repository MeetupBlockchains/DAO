/*
This file is part of the DAO.

The DAO is free software: you can redistribute it and/or modify
it under the terms of the GNU lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DAO is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU lesser General Public License for more details.

You should have received a copy of the GNU lesser General Public License
along with the DAO.  If not, see <http://www.gnu.org/licenses/>.
*/

/**************************************************************************************************

Ce contrat fait parti de la DAO, et s'occupe de la gestion des comptes de la DAO.

Les fonctions incluses sont:
- Paiment à un compte (PayOut)

**************************************************************************************************/

/*
Basic account, used by the DAO contract to separately manage both the rewards
and the extraBalance accounts.
*/

contract ManagedAccountInterface {
    // La seule adresse ayant le droit de retirer des ethers
    address public owner;
    // Si vrai, seul le propriétaire du compte peut recevoir de l'ether
    bool public payOwnerOnly;
    // Le total d'ether (en wei) envoyé au compte
    uint public accumulatedInput;

    // Envoie une somme d'ether _amount à un compte _recipient, retourne bool
    function payOut(address _recipient, uint _amount) returns (bool);

    event PayOut(address indexed _recipient, uint _amount);
}

contract ManagedAccount is ManagedAccountInterface{

    // Le constructeur décide du propriétaire du compte
    function ManagedAccount(address _owner, bool _payOwnerOnly) {
        owner = _owner;
        payOwnerOnly = _payOwnerOnly;
    }

    // Dans le cas où le compte reçoit une transaction d'ether, rajoute la somme au total.
    function() {
        accumulatedInput += msg.value;
    }

    // Envoie de l'ether à l'adresse _recipient. Retourne faux si :
    // - il y a de l'ether dans la tx
    // - le messager n'est pas le propriétaire
    //
    function payOut(address _recipient, uint _amount) returns (bool) {
        if (msg.sender != owner || msg.value > 0 || (payOwnerOnly && _recipient != owner))
            throw;
        if (_recipient.call.value(_amount)()) {
            PayOut(_recipient, _amount);
            return true;
        } else {
            return false;
        }
    }
}
