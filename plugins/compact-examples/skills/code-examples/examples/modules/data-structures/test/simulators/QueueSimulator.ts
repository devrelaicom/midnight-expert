import {
  type BaseSimulatorOptions,
  createSimulator,
} from '@openzeppelin/compact-tools-simulator';
import {
  ledger,
  Contract as MockQueue,
} from '@src/artifacts/structs/test/mocks/contracts/Queue.mock/contract/index.js';
import {
  QueueContractPrivateState,
  QueueWitnesses,
} from './witnesses/Queue.js';

/**
 * Base simulator for Queue mock contract
 */
const QueueSimulatorBase = createSimulator<
  QueueContractPrivateState,
  ReturnType<typeof ledger>,
  ReturnType<typeof QueueWitnesses>,
  MockQueue<QueueContractPrivateState>,
  readonly []
>({
  contractFactory: (witnesses) =>
    new MockQueue<QueueContractPrivateState>(witnesses),
  defaultPrivateState: () => QueueContractPrivateState.generate(),
  contractArgs: () => [],
  ledgerExtractor: (state) => ledger(state),
  witnessesFactory: () => QueueWitnesses(),
});

/**
 * @description A simulator implementation for testing Queue operations.
 */
export class QueueSimulator extends QueueSimulatorBase {
  constructor(
    options: BaseSimulatorOptions<
      QueueContractPrivateState,
      ReturnType<typeof QueueWitnesses>
    > = {},
  ) {
    super([], options);
  }

  /**
   * @description Enqueues an item to the queue.
   * @param item - The item to enqueue.
   */
  public enqueue(item: bigint): void {
    this.circuits.impure.enqueue(item);
  }

  /**
   * @description Dequeues an item from the queue.
   * @returns The dequeued item wrapped in an option (is_some indicates success).
   */
  public dequeue(): { is_some: boolean; value: bigint } {
    return this.circuits.impure.dequeue();
  }

  /**
   * @description Checks if the queue is empty.
   * @returns True if the queue is empty, false otherwise.
   */
  public isEmpty(): boolean {
    return this.circuits.impure.isEmpty();
  }
}
