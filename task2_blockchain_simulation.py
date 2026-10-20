"""
TASK 2 - Immutability Ledger Block Hashing Simulation
A simplified blockchain node engine: blocks, SHA-256 fingerprints,
hash-linking, proof-of-work, and chain validation.
Run:  python task2_blockchain_simulation.py
"""
import hashlib
import json
import time


class Block:
    """Structural schema of one block."""

    def __init__(self, index, transactions, previous_hash, timestamp=None):
        self.index = index
        self.timestamp = timestamp or time.time()
        self.transactions = transactions      # list of dicts
        self.previous_hash = previous_hash    # link to the previous block
        self.nonce = 0
        self.hash = self.calculate_hash()

    def calculate_hash(self):
        """SHA-256 fingerprint of the block's contents."""
        block_data = json.dumps(
            {
                "index": self.index,
                "timestamp": self.timestamp,
                "transactions": self.transactions,
                "previous_hash": self.previous_hash,
                "nonce": self.nonce,
            },
            sort_keys=True,
        ).encode()
        return hashlib.sha256(block_data).hexdigest()

    def mine(self, difficulty):
        """Proof of work: find a hash that starts with `difficulty` zeros."""
        target = "0" * difficulty
        while not self.hash.startswith(target):
            self.nonce += 1
            self.hash = self.calculate_hash()


class Blockchain:
    def __init__(self, difficulty=3):
        self.difficulty = difficulty
        self.chain = [self.create_genesis_block()]

    def create_genesis_block(self):
        return Block(0, [{"info": "Genesis Block"}], "0" * 64, timestamp=0)

    def latest_block(self):
        return self.chain[-1]

    def add_block(self, transactions):
        """Create a new block linked to the previous block's hash."""
        block = Block(len(self.chain), transactions, self.latest_block().hash)
        block.mine(self.difficulty)
        self.chain.append(block)
        return block

    def is_chain_valid(self):
        """Loop through the chain and verify hashes + links."""
        for i in range(1, len(self.chain)):
            current, previous = self.chain[i], self.chain[i - 1]
            if current.hash != current.calculate_hash():
                print(f"[X] Block {i}: stored hash does not match its data (data tampered)")
                return False
            if current.previous_hash != previous.hash:
                print(f"[X] Block {i}: previous_hash does not match Block {i - 1}'s hash (broken link)")
                return False
            if not current.hash.startswith("0" * self.difficulty):
                print(f"[X] Block {i}: proof of work is invalid")
                return False
        return True

    def print_chain(self):
        for b in self.chain:
            print(f"\nBlock #{b.index}")
            print(f"  Timestamp     : {b.timestamp}")
            print(f"  Transactions  : {b.transactions}")
            print(f"  Nonce         : {b.nonce}")
            print(f"  Previous Hash : {b.previous_hash}")
            print(f"  Hash          : {b.hash}")


if __name__ == "__main__":
    print("=== Mining blocks... ===")
    bc = Blockchain(difficulty=3)
    bc.add_block([{"from": "Alice", "to": "Bob", "amount": 50}])
    bc.add_block([{"from": "Bob", "to": "Charlie", "amount": 20},
                  {"from": "Alice", "to": "Dave", "amount": 10}])
    bc.add_block([{"from": "Charlie", "to": "Alice", "amount": 5}])

    bc.print_chain()

    print("\n=== Validating original chain ===")
    print("Chain valid?", bc.is_chain_valid())

    print("\n=== Tampering with Block 1 (Alice->Bob 50 changed to 5000) ===")
    bc.chain[1].transactions[0]["amount"] = 5000
    print("Chain valid?", bc.is_chain_valid())

    print("\n=== Attacker recalculates Block 1's hash (but cannot fix the links) ===")
    bc.chain[1].hash = bc.chain[1].calculate_hash()
    print("Chain valid?", bc.is_chain_valid())
