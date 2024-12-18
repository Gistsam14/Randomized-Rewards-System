
# Randomized Rewards Contract

This project implements a smart contract for a randomized rewards system. Users can participate in a reward pool, and a random winner is selected each round. The contract is designed to run on the Stacks blockchain using Clarity smart contracts.

## Features

- **Participation**: Users can join the reward pool by invoking the `participate` function.
- **Random Winner Selection**: A winner is selected randomly using block hash as a seed.
- **Round Management**: Each reward round tracks its winner.

## Contract Details

### Constants

- `CONTRACT_OWNER`: The owner of the contract who is authorized to select winners.
- Error Codes:
  - `ERR_NOT_AUTHORIZED`: Error when an unauthorized user attempts restricted actions.
  - `ERR_ALREADY_PARTICIPATED`: Error when a user tries to participate more than once in the same round.
  - `ERR_NO_PARTICIPANTS`: Error when attempting to select a winner without participants.

### Data Maps

- `participants`: Tracks which users have participated.
- `winners`: Stores the winners of each round.

### Data Variables

- `current-round`: Tracks the current round number.
- `participant-count`: Tracks the number of participants in the current round.

### Functions

#### Public Functions

1. `participate`
   - Allows a user to join the reward pool.
   - Throws `ERR_ALREADY_PARTICIPATED` if the user has already joined.

2. `select-winner`
   - Selects a random winner for the current round.
   - Only the `CONTRACT_OWNER` can invoke this function.
   - Throws `ERR_NO_PARTICIPANTS` if no users are in the pool.

#### Read-Only Functions

1. `get-participant-count`
   - Returns the total number of participants.

2. `is-participant`
   - Checks if a given user has participated in the current round.

3. `get-winner-for-round`
   - Retrieves the winner of a specified round.

## Unit Tests

The contract's functionality is thoroughly tested using Vitest. Below are the highlights:

### Test Cases

1. **User Participation**:
   - Ensures users can participate in the reward pool.
   - Prevents duplicate participation by the same user.

2. **Winner Selection**:
   - Verifies only the `CONTRACT_OWNER` can select winners.
   - Ensures proper error handling when there are no participants.

3. **State Management**:
   - Confirms that winners are tracked correctly across rounds.

### Running the Tests

To run the tests, ensure you have [Vitest](https://vitest.dev/) installed. Then execute:

```bash
vitest run
```

## Example Usage

### Participate in the Reward Pool

```clarity
(define-public (participate)
  (ok true))
```

### Select a Winner

```clarity
(define-public (select-winner)
  (ok true))
```

### Retrieve Winner for a Round

```clarity
(define-read-only (get-winner-for-round (round uint))
  (map-get? winners { round: round }))
```

## Project Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/randomized-rewards-contract.git
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run the tests:
   ```bash
   npm test
   ```

## License

This project is licensed under the MIT License.
