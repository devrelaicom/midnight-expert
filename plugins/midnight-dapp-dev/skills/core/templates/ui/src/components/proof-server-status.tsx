import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { useWallet } from "@/hooks/use-wallet";

export function ProofServerStatus() {
  const { connectedApi, status } = useWallet();
  const [isOnline, setIsOnline] = useState<boolean | null>(null);

  useEffect(() => {
    if (status !== "connected" || !connectedApi) {
      setIsOnline(null);
      return;
    }

    let cancelled = false;

    async function check() {
      try {
        const config = await connectedApi!.getConfiguration();
        const proofServerUrl = config.substrateNodeUri
          .replace(/\/rpc$/, "")
          .replace(/:9944/, ":6300");
        const response = await fetch(proofServerUrl, { mode: "no-cors" });
        if (!cancelled) setIsOnline(response.type === "opaque" || response.ok);
      } catch {
        if (!cancelled) setIsOnline(false);
      }
    }

    check();
    return () => {
      cancelled = true;
    };
  }, [connectedApi, status]);

  if (isOnline === null) return null;

  return (
    <Badge variant={isOnline ? "secondary" : "destructive"}>
      Proof Server: {isOnline ? "Online" : "Offline"}
    </Badge>
  );
}
