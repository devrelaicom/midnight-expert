import { WitnessContext } from "@midnight-ntwrk/compact-runtime";
import { Ledger, Witnesses } from "./managed/ticket/contract/index.js";
import crypto from "node:crypto";

// Private state holds the ticket secret and randomness.
// Each ticket has a unique secret + randomness pair.
export type TicketPrivateState = {
  readonly secret: Uint8Array;
  readonly randomness: Uint8Array;
};

export function createTicketState(): TicketPrivateState {
  return {
    secret: crypto.randomBytes(32),
    randomness: crypto.randomBytes(32),
  };
}

export const ticketWitnesses: Witnesses<TicketPrivateState> = {
  // Return the ticket secret from private state
  ticket_secret: ({
    privateState,
  }: WitnessContext<Ledger, TicketPrivateState>): [TicketPrivateState, Uint8Array] => [
    privateState,
    privateState.secret,
  ],

  // Return the randomness from private state
  ticket_randomness: ({
    privateState,
  }: WitnessContext<Ledger, TicketPrivateState>): [TicketPrivateState, Uint8Array] => [
    privateState,
    privateState.randomness,
  ],

  // Look up the Merkle path for a commitment in the on-chain tree.
  // The context gives us access to the current ledger state.
  get_ticket_path: (
    { privateState, ledger: contractLedger }: WitnessContext<Ledger, TicketPrivateState>,
    commitment: Uint8Array,
  ): [TicketPrivateState, { leaf: Uint8Array; path: { sibling: { field: bigint }; goes_left: boolean }[] }] => {
    // Use the ledger's findPathForLeaf to get the Merkle proof
    const merklePath = contractLedger.tickets.findPathForLeaf(commitment);
    if (!merklePath) {
      throw new Error("Ticket commitment not found in tree");
    }
    return [privateState, merklePath];
  },
};
