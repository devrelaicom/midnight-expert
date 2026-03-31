import { useEffect, useState } from "react";
import type { Observable } from "rxjs";

export function useContractState<T>(observable: Observable<T> | null): {
  state: T | null;
  error: Error | null;
} {
  const [state, setState] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!observable) {
      setState(null);
      setError(null);
      return;
    }

    const subscription = observable.subscribe({
      next: (value) => {
        setState(value);
        setError(null);
      },
      error: (err) => {
        setError(err instanceof Error ? err : new Error(String(err)));
      },
    });

    return () => subscription.unsubscribe();
  }, [observable]);

  return { state, error };
}
