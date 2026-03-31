import { Wallet, LogOut, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useWallet } from "@/hooks/use-wallet";

function truncateAddress(address: string): string {
  if (address.length <= 16) return address;
  return `${address.slice(0, 8)}...${address.slice(-8)}`;
}

export function WalletWidget() {
  const { status, shieldedAddress, error, connect, disconnect } = useWallet();

  if (status === "connecting") {
    return (
      <Button variant="outline" disabled>
        <Loader2 className="animate-spin" />
        Connecting...
      </Button>
    );
  }

  if (status === "connected" && shieldedAddress) {
    return (
      <div className="flex items-center gap-2">
        <span className="text-sm font-mono text-muted-foreground">
          {truncateAddress(shieldedAddress)}
        </span>
        <Button variant="ghost" size="icon" onClick={disconnect}>
          <LogOut />
        </Button>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <Button variant="outline" onClick={connect}>
        <Wallet />
        Connect Wallet
      </Button>
      {status === "error" && error && (
        <p className="text-xs text-destructive max-w-64 text-right">{error}</p>
      )}
    </div>
  );
}
