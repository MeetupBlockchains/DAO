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

Ce contrat fait parti de la DAO, et s'occupe de la création des tokens / jetons de la DAO ainsi que
l'initialisation des ethers.

Les fonctions incluses sont:
- Création de tokens (createTokenProxy)
- Remboursement (refund)
- Acquisition du taux ETH/Token (divisor)

**************************************************************************************************/

import "./Token.sol";
import "./ManagedAccount.sol";

contract TokenCreationInterface {

    // Date de fin du crowdfunding, en temps Unix
    uint public closingTime;
    // Montant minimal de tokens à générer pour que le crowdfunding soit considéré comme réussi
    uint public minTokensToCreate;
    // Vrai si l'objectif est atteint, faux sinon
    bool public isFueled;
    // For DAO splits -
    // Si privatecreation est égal à 0, la création de tokens est décidé publiquement (par consensus)
    // Sinon le compte en question gère la création de tokens
    address public privateCreation;
    // Après que le taux de création des DAO est augmenté, les ethers "supplémentaires" sont envoyés à
    // l'adresse du compte "extraBalance"
    ManagedAccount public extraBalance;
    // liste des ethers (en wei) envoyés par chaque adresse (pour le remboursement)
    mapping (address => uint256) weiGiven;

    /* Le constructeur du contrat, mis en commentaire */
    /// @dev Constructor setting the minimum fueling goal and the
    /// end of the Token Creation
    /// @param _minTokensToCreate Minimum fueling goal in number of
    ///        Tokens to be created
    /// @param _closingTime Date (in Unix time) of the end of the Token Creation
    /// @param _privateCreation Zero means that the creation is public.  A
    /// non-zero address represents the only address that can create Tokens
    /// (the address can also create Tokens on behalf of other accounts)
    // This is the constructor: it can not be overloaded so it is commented out
    //  function TokenCreation(
        //  uint _minTokensTocreate,
        //  uint _closingTime,
        //  address _privateCreation
    //  );

    // Créé des tokens pour l'adresse _tokenHolder, retourne le succès, ou non.
    function createTokenProxy(address _tokenHolder) returns (bool success);

    // Rembourse le compte le demandant (msg.sender) si le montant minimum n'est pas atteint
    function refund();

    // Retourne à tout moment la valeur actuel du taux ETH/DAOToken
    function divisor() constant returns (uint divisor);

    event FuelingToDate(uint value);
    event CreatedToken(address indexed to, uint amount);
    event Refund(address indexed to, uint value);
}


contract TokenCreation is TokenCreationInterface, Token {
    // Constructeur, prends en entrée le montant minimal de tokens à créer, la date de clôture du crowdfunding,
    // ainsi que l'adresse (ou non) du compte pouvant créer des tokens.
    function TokenCreation(
        uint _minTokensToCreate,
        uint _closingTime,
        address _privateCreation) {

        closingTime = _closingTime;
        minTokensToCreate = _minTokensToCreate;
        privateCreation = _privateCreation;
        extraBalance = new ManagedAccount(address(this), true);
    }

    // Fonction de création des tokens.
    // Vérifie que la date de clôture n'est pas atteint, que l'on envoie des ethers et que le
    // compte est autorisé (toujours ou juste le compte "privateCreation").
    //
    // Créer ensuite un nombre de token en fonction de l'ether envoyé et le taux ETH/DAO.
    // Incrémente ensuite le nombre de tokens total (et vérifie si l'objectif est atteint)
    function createTokenProxy(address _tokenHolder) returns (bool success) {
        if (now < closingTime && msg.value > 0
            && (privateCreation == 0 || privateCreation == msg.sender)) {

            uint token = (msg.value * 20) / divisor();
            extraBalance.call.value(msg.value - token)();
            balances[_tokenHolder] += token;
            totalSupply += token;
            weiGiven[_tokenHolder] += msg.value;
            CreatedToken(_tokenHolder, token);
            if (totalSupply >= minTokensToCreate && !isFueled) {
                isFueled = true;
                FuelingToDate(totalSupply);
            }
            return true;
        }
        throw;
    }

    // Remboursement si les conditions n'ont pas été atteinte. (ne fonctionne qu'une fois)
    // nb: vérifie qu'on envoie pas d'ether
    function refund() noEther {
        if (now > closingTime && !isFueled) {
            // Get extraBalance - will only succeed when called for the first time
            if (extraBalance.balance >= extraBalance.accumulatedInput())
                extraBalance.payOut(address(this), extraBalance.accumulatedInput());

            // Execute refund
            if (msg.sender.call.value(weiGiven[msg.sender])()) {
                Refund(msg.sender, weiGiven[msg.sender]);
                totalSupply -= balances[msg.sender];
                balances[msg.sender] = 0;
                weiGiven[msg.sender] = 0;
            }
        }
    }

    // Taux ETH/Token en fonction du temps
    function divisor() constant returns (uint divisor) {
        // The number of (base unit) tokens per wei is calculated
        // as `msg.value` * 20 / `divisor`
        // The fueling period starts with a 1:1 ratio
        if (closingTime - 2 weeks > now) {
            return 20;
        // Followed by 10 days with a daily creation rate increase of 5%
        } else if (closingTime - 4 days > now) {
            return (20 + (now - (closingTime - 2 weeks)) / (1 days));
        // The last 4 days there is a constant creation rate ratio of 1:1.5
        } else {
            return 30;
        }
    }
}
