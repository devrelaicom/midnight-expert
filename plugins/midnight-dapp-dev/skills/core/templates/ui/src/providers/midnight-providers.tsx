import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import { createProviders, type AppProviders } from "{{API_PACKAGE_NAME}}";
import { useWallet } from "@/hooks/use-wallet";

interface MidnightProvidersContextValue {
  providers: AppProviders | null;
  isReady: boolean;
  error: string | null;
}

const MidnightProvidersContext =
  createContext<MidnightProvidersContextValue | null>(null);

export function MidnightProvidersProvider({
  children,
}: {
  children: ReactNode;
}) {
  const { connectedApi, status } = useWallet();
  const [providers, setProviders] = useState<AppProviders | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (status !== "connected" || !connectedApi) {
      setProviders(null);
      setError(null);
      return;
    }

    let cancelled = false;

    createProviders(connectedApi)
      .then((p) => {
        if (!cancelled) {
          setProviders(p);
          setError(null);
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setError(
            err instanceof Error ? err.message : "Failed to create providers",
          );
        }
      });

    return () => {
      cancelled = true;
    };
  }, [connectedApi, status]);

  return (
    <MidnightProvidersContext.Provider
      value={{ providers, isReady: providers !== null, error }}
    >
      {children}
    </MidnightProvidersContext.Provider>
  );
}

export function useMidnightProviders(): MidnightProvidersContextValue {
  const context = useContext(MidnightProvidersContext);
  if (!context) {
    throw new Error(
      "useMidnightProviders must be used within a MidnightProvidersProvider",
    );
  }
  return context;
}
