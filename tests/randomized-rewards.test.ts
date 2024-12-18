import { describe, it, expect, beforeEach } from 'vitest';

// Mocking blockchain state and contract functions
type Participant = {
  address: string;
  hasParticipated: boolean;
};

type Winner = {
  round: number;
  address: string;
};

let participants: Map<string, Participant>;
let winners: Map<number, Winner>;
let participantCount: number;
let currentRound: number;

const CONTRACT_OWNER = "wallet_owner";

beforeEach(() => {
  participants = new Map();
  winners = new Map();
  participantCount = 0;
  currentRound = 0;
});

// Contract functions to test
const participate = (user: string) => {
  if (participants.has(user) && participants.get(user)?.hasParticipated) {
    throw new Error("ERR_ALREADY_PARTICIPATED");
  }
  participants.set(user, { address: user, hasParticipated: true });
  participantCount++;
  return true;
};

const selectWinner = (caller: string, blockHash: string) => {
  if (caller !== CONTRACT_OWNER) {
    throw new Error("ERR_NOT_AUTHORIZED");
  }
  if (participantCount === 0) {
    throw new Error("ERR_NO_PARTICIPANTS");
  }

  // Simulate randomness using the block hash
  const hashAsNumber = parseInt(blockHash.substring(0, 16), 16); // Use first 16 chars of hash as uint
  const winnerIndex = hashAsNumber % participantCount;

  const participantArray = Array.from(participants.keys());
  const winnerAddress = participantArray[winnerIndex];

  winners.set(currentRound, { round: currentRound, address: winnerAddress });
  currentRound++;
  return winnerAddress;
};

// Tests using Vitest
describe("Randomized Rewards Contract", () => {
  const user1 = "wallet_1";
  const user2 = "wallet_2";
  const invalidUser = "wallet_invalid";

  beforeEach(() => {
    // Reset state before each test
    participants.clear();
    winners.clear();
    participantCount = 0;
    currentRound = 0;
  });

  it("should allow a user to participate", () => {
    expect(participate(user1)).toBe(true);
    expect(participants.has(user1)).toBe(true);
    expect(participantCount).toBe(1);
  });

  it("should throw an error if a user participates twice", () => {
    participate(user1);
    expect(() => participate(user1)).toThrow("ERR_ALREADY_PARTICIPATED");
  });

  it("should select a winner when called by the contract owner", () => {
    participate(user1);
    participate(user2);

    const blockHash = "abcd1234abcd1234abcd1234abcd1234";
    const winner = selectWinner(CONTRACT_OWNER, blockHash);

    expect(winner).toBeDefined();
    expect(winners.get(0)?.address).toBe(winner);
    expect(currentRound).toBe(1);
  });

  it("should throw an error if called by a non-owner", () => {
    participate(user1);
    const blockHash = "abcd1234abcd1234abcd1234abcd1234";

    expect(() => selectWinner(invalidUser, blockHash)).toThrow("ERR_NOT_AUTHORIZED");
  });

  it("should throw an error if no participants exist", () => {
    const blockHash = "abcd1234abcd1234abcd1234abcd1234";

    expect(() => selectWinner(CONTRACT_OWNER, blockHash)).toThrow("ERR_NO_PARTICIPANTS");
  });

  it("should handle multiple winners across rounds", () => {
    participate(user1);
    participate(user2);

    const blockHash1 = "abcd1234abcd1234abcd1234abcd1234";
    const blockHash2 = "1234abcd1234abcd1234abcd1234abcd";

    const winner1 = selectWinner(CONTRACT_OWNER, blockHash1);
    const winner2 = selectWinner(CONTRACT_OWNER, blockHash2);

    expect(winners.get(0)?.address).toBe(winner1);
    expect(winners.get(1)?.address).toBe(winner2);
    expect(currentRound).toBe(2);
  });

  it("should correctly reset state before each test", () => {
    expect(participants.size).toBe(0);
    expect(winners.size).toBe(0);
    expect(participantCount).toBe(0);
    expect(currentRound).toBe(0);
  });
});
