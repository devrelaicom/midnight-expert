import { Badge } from "@/components/ui/badge";
import { useWallet } from "@/hooks/use-wallet";

export function NetworkBadge() {
  const { networkId, status } = useWallet();

  if (status !== "connected" || !networkId) return null;

  return <Badge variant="secondary">{networkId}</Badge>;
}
