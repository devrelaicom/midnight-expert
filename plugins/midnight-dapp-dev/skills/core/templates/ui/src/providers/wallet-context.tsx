import {
  createContext,
  useCallback,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import type { ConnectedAPI, InitialAPI } from "@midnight-ntwrk/dapp-connector-api";

const STORAGE_KEY = "{{PROJECT_NAME}}_wallet_autoconnect";

export type WalletConnectionStatus =
  | "disconnected"
  | "connecting"
  | "connected"
  | "error";

export interface WalletState {
  status: WalletConnectionStatus;
  connectedApi: ConnectedAPI | null;
  shieldedAddress: string | null;
  coinPublicKey: string | null;
  encryptionPublicKey: string | null;
  networkId: string | null;
  error: string | null;
}

export interface WalletContextValue extends WalletState {
  connect: () => Promise<void>;
  disconnect: () => void;
}

export const WalletContext = createContext<WalletContextValue | null>(null);

function findWallet(): InitialAPI | undefined {
  if (typeof window === "undefined" || !window.midnight) return undefined;
  return window.midnight.mnLace ?? Object.values(window.midnight)[0];
}

export function WalletProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<WalletState>({
    status: "disconnected",
    connectedApi: null,
    shieldedAddress: null,
    coinPublicKey: null,
    encryptionPublicKey: null,
    networkId: null,
    error: null,
  });

  const connect = useCallback(async () => {
    setState((prev) => ({ ...prev, status: "connecting", error: null }));

    const wallet = findWallet();
    if (!wallet) {
      setState((prev) => ({
        ...prev,
        status: "error",
        error:
          "Lace wallet extension not found. Install it from the Chrome Web Store.",
      }));
      return;
    }

    try {
      const api = await wallet.connect("undeployed");
      const config = await api.getConfiguration();
      const addresses = await api.getShieldedAddresses();

      setState({
        status: "connected",
        connectedApi: api,
        shieldedAddress: addresses.shieldedAddress,
        coinPublicKey: addresses.shieldedCoinPublicKey,
        encryptionPublicKey: addresses.shieldedEncryptionPublicKey,
        networkId: config.networkId,
        error: null,
      });

      localStorage.setItem(STORAGE_KEY, "true");
    } catch (err: unknown) {
      const message =
        typeof err === "object" && err !== null && "reason" in err
          ? (err as { reason: string }).reason
          : "Failed to connect to wallet";
      setState((prev) => ({
        ...prev,
        status: "error",
        error: message,
      }));
    }
  }, []);

  const disconnect = useCallback(() => {
    localStorage.removeItem(STORAGE_KEY);
    setState({
      status: "disconnected",
      connectedApi: null,
      shieldedAddress: null,
      coinPublicKey: null,
      encryptionPublicKey: null,
      networkId: null,
      error: null,
    });
  }, []);

  useEffect(() => {
    if (localStorage.getItem(STORAGE_KEY) === "true") {
      connect();
    }
  }, [connect]);

  return (
    <WalletContext.Provider value={{ ...state, connect, disconnect }}>
      {children}
    </WalletContext.Provider>
  );
}
