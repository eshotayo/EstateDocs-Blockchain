# EstateDocs-Blockchain

## Overview
EstateDocs-Blockchain is a decentralized system built on the Clarity smart contract language to manage and secure property documents. The protocol allows users to register, transfer, update, and validate property documents on the blockchain, with built-in access control and ownership verification mechanisms. This solution ensures transparency, security, and immutability in property document management.

## Features
- **Document Registration**: Securely registers property documents with metadata like title, description, file size, and tags.
- **Ownership Management**: Enables ownership transfer of property documents.
- **Access Control**: Allows owners to grant or revoke access permissions for viewers.
- **Document Updates**: Supports updating document metadata (title, description, tags).
- **Security Locks**: Place security holds on documents to prevent tampering.
- **Document Validation**: Verifies document authenticity and ownership history.
- **Archiving**: Archive documents while maintaining ownership records.

## System Requirements
- Clarity-compatible blockchain (e.g., Stacks blockchain).
- A wallet or environment that can interact with Clarity smart contracts.

## Installation

Clone the repository:

```bash
git clone https://github.com/yourusername/EstateDocs-Blockchain.git
```

Navigate to the project directory:

```bash
cd EstateDocs-Blockchain
```

Deploy the smart contracts to a Clarity-compatible blockchain using your preferred deployment tool (e.g., Stacks CLI or a compatible web interface).

## Usage

### Register a Document
```clarity
(register-document "Property Title" 2048 "Property Description" ["Tag1", "Tag2", "Tag3"])
```

### Transfer Document Ownership
```clarity
(transfer-document 1 new-owner-principal)
```

### Add Tags to Document
```clarity
(add-document-tags 1 ["NewTag1", "NewTag2"])
```

### Archive a Document
```clarity
(archive-document 1)
```

## Functions Overview

### `register-document`
- Registers a new document with metadata and tags.

### `transfer-document`
- Transfers ownership of a registered document to a new owner.

### `add-document-tags`
- Adds tags to a document for easy classification.

### `archive-document`
- Archives a document while retaining ownership records and tags.

### `verify-document-authenticity`
- Verifies the authenticity of a document and its ownership history.

## Error Handling
- `err-document-not-found`: Document does not exist.
- `err-unauthorized-owner`: Caller is not the document owner.
- `err-tag-validation-failed`: Invalid tag format.

## Contributing
We welcome contributions! If you'd like to improve this project, feel free to fork the repository and submit a pull request.

### License
This project is licensed under the MIT License.
