import { WitnessContext } from "@midnight-ntwrk/compact-runtime";
import { Ledger, Witnesses } from "./managed/counter/contract/index.js";

export const witnesses: Witnesses<undefined> = {
  get_increment_amount: (
    context: WitnessContext<Ledger, undefined>
  ): [undefined, bigint] => [undefined, 1n],
};
