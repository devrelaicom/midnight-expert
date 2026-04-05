import { beforeEach, describe, expect, test } from 'vitest';
import { QueueSimulator } from './mocks/QueueSimulator.js';

let mockQueueContract: QueueSimulator;

const setup = () => {
  mockQueueContract = new QueueSimulator();
};

describe('Queue', () => {
  beforeEach(setup);

  describe('Enqueue', () => {
    test('should enqueue single item', () => {
      mockQueueContract.enqueue(0n);
      const state = mockQueueContract.getPublicState();
      expect(state.Queue_state.member(0n)).toBeTruthy();
      expect(state.Queue_state.lookup(0n)).toBe(0n);
      expect(state.Queue_head).toBe(0n);
      expect(state.Queue_tail).toBe(1n);
    });

    test('should enqueue multiple items sequentially', () => {
      mockQueueContract.enqueue(0n);
      mockQueueContract.enqueue(100n);
      mockQueueContract.enqueue(200n);
      const state = mockQueueContract.getPublicState();
      expect(state.Queue_state.member(0n)).toBeTruthy();
      expect(state.Queue_state.lookup(0n)).toBe(0n);
      expect(state.Queue_state.member(1n)).toBeTruthy();
      expect(state.Queue_state.lookup(1n)).toBe(100n);
      expect(state.Queue_state.member(2n)).toBeTruthy();
      expect(state.Queue_state.lookup(2n)).toBe(200n);
      expect(state.Queue_head).toBe(0n);
      expect(state.Queue_tail).toBe(3n);
    });

    test('should not mark queue as empty after enqueue', () => {
      mockQueueContract.enqueue(0n);
      expect(mockQueueContract.isEmpty()).toBeFalsy();
    });

    test('should handle large number of enqueues', () => {
      for (let i = 0n; i < 100n; i++) {
        mockQueueContract.enqueue(i);
      }
      const state = mockQueueContract.getPublicState();
      expect(state.Queue_state.member(99n)).toBeTruthy();
      expect(state.Queue_state.lookup(99n)).toBe(99n);
      expect(state.Queue_tail).toBe(100n);
      expect(state.Queue_head).toBe(0n);
    });
  });

  describe('Dequeue', () => {
    test('should dequeue single item', () => {
      mockQueueContract.enqueue(0n);
      const result = mockQueueContract.dequeue();
      expect(result.value).toBe(0n);
      const state = mockQueueContract.getPublicState();
      expect(state.Queue_state.member(0n)).toBeFalsy();
      expect(state.Queue_head).toBe(1n);
      expect(state.Queue_tail).toBe(1n);
    });

    test('should dequeue multiple items in FIFO order', () => {
      mockQueueContract.enqueue(0n);
      mockQueueContract.enqueue(100n);
      mockQueueContract.enqueue(200n);

      let result = mockQueueContract.dequeue();
      expect(result.value).toBe(0n);
      expect(
        mockQueueContract.getPublicState().Queue_state.member(0n),
      ).toBeFalsy();

      result = mockQueueContract.dequeue();
      expect(result.value).toBe(100n);
      expect(
        mockQueueContract.getPublicState().Queue_state.member(1n),
      ).toBeFalsy();

      result = mockQueueContract.dequeue();
      expect(result.value).toBe(200n);
      const state = mockQueueContract.getPublicState();
      expect(state.Queue_state.member(2n)).toBeFalsy();
      expect(state.Queue_head).toBe(3n);
      expect(state.Queue_tail).toBe(3n);
    });

    test('should return none when dequeuing empty queue', () => {
      const result = mockQueueContract.dequeue();
      expect(result.is_some).toBe(false);
      const state = mockQueueContract.getPublicState();
      expect(state.Queue_head).toBe(0n);
      expect(state.Queue_tail).toBe(0n);
    });

    test('should mark queue as empty after dequeuing all items', () => {
      mockQueueContract.enqueue(0n);
      mockQueueContract.enqueue(100n);
      mockQueueContract.dequeue();
      mockQueueContract.dequeue();
      expect(mockQueueContract.isEmpty()).toBeTruthy();
    });

    test('should handle dequeue after large enqueue', () => {
      for (let i = 0n; i < 50n; i++) {
        mockQueueContract.enqueue(i);
      }
      for (let i = 0n; i < 50n; i++) {
        const result = mockQueueContract.dequeue();
        expect(result.value).toBe(i);
      }
      expect(mockQueueContract.isEmpty()).toBeTruthy();
    });

    test('should maintain sparse keys without shifting', () => {
      mockQueueContract.enqueue(0n);
      mockQueueContract.enqueue(100n);
      mockQueueContract.dequeue(); // Removes 0n at head=0
      const state = mockQueueContract.getPublicState();
      expect(state.Queue_state.member(0n)).toBeFalsy();
      expect(state.Queue_state.member(1n)).toBeTruthy();
      expect(state.Queue_head).toBe(1n);
      expect(state.Queue_tail).toBe(2n);
    });
  });
});
