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

Ce fichier fait parti de la DAO, et s'occupe de la gestion des tokens / jetons de la DAO.

Les fonctions incluses sont:
- Vérification du solde d'un compte (CheckToken)
- Envoie de token (sendtoken)
- Envoie de token pour un tiers + vérification

La création de ces tokens se fait via un contrat tier (TokenCreation.sol)

Ce contrat a été originellement écrit par ConsenSys et adapté par Slock.it :
https://github.com/ConsenSys/Tokens/blob/master/Token_Contracts/contracts/Standard_Token.sol

**************************************************************************************************/

/// @title Standard Token Contract.

contract TokenInterface {
    mapping (address => uint256) balances; // balance des possesseurs de DAO tokens
    mapping (address => mapping (address => uint256)) allowed; // autorisation de transfert par une autre adresse

    /// Montant total des tokens DAO (En entier, donc avec les décimales !)
    uint256 public totalSupply;

    /* Liste des paramètres */

    // Retourne le solde d'un compte
    function balanceOf(address _owner) constant returns (uint256 balance);

    // Transfère le montant _amount au compte _to, et retourne le succès ou non du transfert
    function transfer(address _to, uint256 _amount) returns (bool success);

    // Transfère le montant _amount au compte _to, depuis le compte _from. (retourne le succès, ou non)
    // Cette fonction permet de transférer depuis un compte tiers (approuvé par la fonction approve)
    function transferFrom(address _from, address _to, uint256 _amount) returns (bool success);

    // Permet d'approuver l'utilisation de son compte pour un transfert d'un certain montant par un compte tiers
    // Approuve le compte _spender pour un montant de _amount.
    function approve(address _spender, uint256 _amount) returns (bool success);

    // Permet de savoir combien un certain compte _spender peut dépenser de tokens d'un autre compte _owner
    // Le résultat obtenu est le nombre de tokens restant à dépenser
    function allowance(
        address _owner,
        address _spender
    ) constant returns (uint256 remaining);

    // Evénements permettant d'avoir une vue sur le transfert de token et le process d'approbation
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _amount
    );
}


contract Token is TokenInterface {
    // Cette condition (modifier) vérifie que le sender n'envoie pas d'Ether !
    // En effet il n'y a besoin ici que de gas pour payer les transactions,
    // si une personne envoie de l'ether, cette somme sera perdue (non gérée par le contrat)
    // Pour éviter cela, on ajoute cette condition qui rejetera toutes transactions ayant joint de l'ether.
    modifier noEther() {if (msg.value > 0) throw; _}

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    // Simple fonction de transfert. Ok si la balance est suffisante, sinon on rejette
    function transfer(address _to, uint256 _amount) noEther returns (bool success) {
        if (balances[msg.sender] >= _amount && _amount > 0) {
            balances[msg.sender] -= _amount;
            balances[_to] += _amount;
            Transfer(msg.sender, _to, _amount);
            return true;
        } else {
           return false;
        }
    }

    // identique, mais on vérifie d'abord que le compte peut envoyer cette somme depuis le compte ciblé.
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) noEther returns (bool success) {

        if (balances[_from] >= _amount
            && allowed[_from][msg.sender] >= _amount
            && _amount > 0) {

            balances[_to] += _amount;
            balances[_from] -= _amount;
            allowed[_from][msg.sender] -= _amount;
            Transfer(_from, _to, _amount);
            return true;
        } else {
            return false;
        }
    }

    function approve(address _spender, uint256 _amount) returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}
