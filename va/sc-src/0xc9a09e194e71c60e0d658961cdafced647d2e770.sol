/* This source code is part of CACIB DocChain registered trademark
*  It is provided becaused published in the public blockchain of Ethereum.
*  Reusing this code is forbidden without approbation of CACIB first (<a href="/cdn-cgi/l/email-protection" class="__cf_email__" data-cfemail="68010c0d09280b09450b010a460b0705">[email protected]</a>)
*  Providing this code in public repository is meant to provide clarity to the mechanism by which the DocChain product works
*
*  This contract represents a repository of document hashes linked to their signatories IEthIdentity and is the heart of the DocChain product
*/
pragma solidity ^0.4.11;

/**
 * The IEthIdentity interface defines fundamental functionnalities
 * that every Ethereum identity in this framework must implement to be 
 * usable with DocChain principles.
 * 
 * The purpose of implementing IEthIdentity interface is to prove its own identity
 * and let others checking whether any proof has been made by its identity.
 */
interface IEthIdentity {
    
    /**
     * Add proof if it does not exist yet
     *  - address: the smart contract address where the identity proof has been stored (see eSignature contract)
     *  - bytes32: the attribute id or proof id for which the identity owner has made a proof
     */
    function addProof(address, bytes32) public returns(bool);
    
    /**
     * Remove proof of a source if existed
     *  - address: the smart contract address where the identity proof has been stored (see eSignature contract)
     *  - bytes32: the attribute id or proof id to be removed
     */
    function removeProof(address, bytes32) public returns(bool);

    /**
     * Check whether the provided address is the controlling wallet (owner) of the identity
     */
    function checkOwner(address) public constant returns(bool);
    
    /**
     * Get the identity owner name
     */
    function getIdentityName() public constant returns(bytes32);
    
}


contract eSignature {
    
    /**
     * The document structure is composed of:
     * - A hash representing the document
     * - Address of the issuer IEthIdentity who initally creates the document
     * - A mapping list of all signing IEthIdentity that approve the document
     */
    struct DocStruct {
        bytes32 hash;
        IEthIdentity issuerIdentity;

        uint nbSignatories;                             // counter of signatories
        mapping(address => bool) signatoryAddresses;    // mapping to know if an address is a signatory
        mapping(uint => IEthIdentity) signatories;      // mapping to get a signatory by position
    }

    /**
     * The eSignature contract contains two data points:
     * - A mapping list of documents existing in eSignature contract
     * - A counter to keep track the number of existing documents in the list
     */
    uint public count;
    mapping(bytes20 => DocStruct) docs;
    
    /**
     * This event is used for notifying new document created
     * - key: document id generated by eSignature contract
     */
    event DocCreated(bytes20 key);
    
    /**
     * This event is used for notifying a new approval of a document
     * - key: document id generated by eSignature contract
     * - identity: address of signing IEthIdentity
     */
    event DocSigned(bytes20 key, IEthIdentity identity);
    
    /**
     * Create new document that is represented by its hash
     * Return the id of created document
     * - hash: hash string of the document content
     * - issuerId: address of EthIdentiy of issuer
     */
    function newDoc(bytes32 hash, IEthIdentity issuerId) public returns (bytes20 docKey) {
        
        /* Warning: Potential Violation of Checks-Effects-Interaction pattern 
            If the issuerId is 0x00 or a fake address it will fail
            If the caller passes its own implementation of IEthIdentity to attempt re-entrant code 
                it will call itself recursively first consuming all its gas and not altering the smart contract
            If the caller passes an identity implementation that returns true always and calls newDoc again
                two (or more) documents will be created with different docKey not altering the mechanism
        */
        // Check if valid identity via inter-contract call, limit gas used for this call
        require(issuerId.checkOwner.gas(800)(msg.sender)); 
        
        // Generate the document Id and save to mapping
        count++;
        docKey = ripemd160(issuerId, count);
        
        // Additional check that docKey not exists to avoid overriding
        assert(checkExists(docKey) == false);
        
        docs[docKey].issuerIdentity = issuerId;
        docs[docKey].hash = hash;
        // docs[docKey].nbSignatories is by construction initialized to zero.
        
        DocCreated(docKey);
    }
    
    /**
     * Create and sign a new document that is represented by its hash
     * Return the id of created signed document
     * - hash: unique hash string of the document content
     * - ethIdentity: address of EthIdentiy of signer that allow to verify the signer's authenticity
     */
    function newSignedDoc(bytes32 hash, IEthIdentity ethIdentity) public returns (bytes20 docKey) {
        // Create & sign a new document
        docKey = newDoc(hash, ethIdentity);
        
        // Verify document & check if it is already signed by the current ethIdentity
        require(docs[docKey].signatoryAddresses[ethIdentity] == false); // Prevent re-signing document by the same signer
        
        docs[docKey].signatoryAddresses[ethIdentity] = true;
        docs[docKey].signatories[docs[docKey].nbSignatories] = ethIdentity;
        docs[docKey].nbSignatories++;
        
        DocSigned(docKey, ethIdentity);
    }
    
    /**
     * Sign an existing document with a valid IEthIdentity of signer
     * - key: unique id of the created document
     * - ethIdentity: address of EthIdentiy of signer that allow to verify the signer's authenticity
     */
    function signDoc(bytes20 docKey, IEthIdentity ethIdentity) public {
        
        /* Warning: Potential Violation of Checks-Effects-Interaction pattern 
            If the issuerId is 0x00 or a fake address it will fail
            If the caller passes its own implementation of IEthIdentity to attempt re-entrant code 
                it will call itself recursively first consuming all its gas and not altering the smart contract
            If the caller passes an identity implementation that returns true always and calls signDoc again
                the second check will prevent corrupting the logic
        */
        // Check if valid identity via inter-contract call, limit gas used for this call
        require(ethIdentity.checkOwner.gas(800)(msg.sender)); 

        // Verify document & check if it is already signed by the current ethIdentity
        require(docs[docKey].signatoryAddresses[ethIdentity] == false); // Prevent re-signing document by the same signer
        
        docs[docKey].signatoryAddresses[ethIdentity] = true;
        docs[docKey].signatories[docs[docKey].nbSignatories] = ethIdentity;
        docs[docKey].nbSignatories++;
        
        DocSigned(docKey, ethIdentity);
    }
    
    /**
     * Get the document information by its id key. 
     * Return a tuple containing the document's hash, its issuers and number of signatories
     * - key: a unique id of the created document
     */
    function getDoc(bytes20 docKey) public constant returns (bytes32 hash, IEthIdentity issuer, uint nbSignatories) {
        
        // Check if document exists by its key
        if (checkExists(docKey)) 
            return (docs[docKey].hash, docs[docKey].issuerIdentity, docs[docKey].nbSignatories);
        else  // returns a tupple saying the key is not valid
            return ("No a valid key", IEthIdentity(0x0), 0);
    }
    
    /**
     * Get the specific signatory of a given document by its id key
     * Return a tuple containing the EthIdentity address and name of signatory
     * - key: a unique key representing the created document
     * - index: index of the signatory to get its information
     */
    function getSignatory(bytes20 docKey, uint index) public constant returns (IEthIdentity identity, string identityName) {

        // Check if document exists by its key
        if (checkExists(docKey)) {
        
            // Check index is not outbound
            require(index < docs[docKey].nbSignatories);
            
            identity = docs[docKey].signatories[index];
            // Get the signatory information from its identity contract
            identityName = bytes32ToString(identity.getIdentityName());
                    
            return (identity, identityName); 
        } else {
            return (IEthIdentity(0x0), "");
        }    
    }
    
    /**
     * Check if a document exists by its key
     * Return true/false indicating the document existance
     * - key: a unique key representing the created document
     */
    function checkExists(bytes20 docKey) public constant returns(bool) {
        // Document exists only if its issuer is valid
        return docs[docKey].issuerIdentity != address(0x0);
    }
    
    /**
     * Convert bytes32 to string. Set modifier pure which means cannot
     * access the contract storage.
     */
    function bytes32ToString (bytes32 data) internal pure returns (string) {
        bytes memory bytesString = new bytes(32);
        for (uint j=0; j<32; j++){
            if (data[j] != 0) {
                bytesString[j] = data[j];
            }
        }
        return string(bytesString);
    }
}