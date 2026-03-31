import path from "node:path";

// File system
export const STATE_DIR = ".midnight-expert";
export const WALLETS_FILE = "wallets.json";
export const CONTRACTS_FILE = "deployed-contracts.json";
export const INIT_MARKER = ".initialized";
export const DIR_MODE = 0o700;
export const FILE_MODE_PRIVATE = 0o600;
export const FILE_MODE_PUBLIC = 0o644;

// Wallet
export const GENESIS_SEED = "0000000000000000000000000000000000000000000000000000000000000001";
export const SEED_LENGTH = 64; // hex chars = 32 bytes

// Network
export const DEFAULT_TTL_MINUTES = 10;

// Fees
export const ADDITIONAL_FEE_OVERHEAD = 300_000_000_000_000n;
export const FEE_BLOCKS_MARGIN = 5;
export const DUST_MIN_REQUIREMENT = 800_000_000_000_000n;

// Timeouts (ms)
export const WALLET_SYNC_TIMEOUT = 120_000;
export const DUST_GENERATION_TIMEOUT = 120_000;
export const DUST_POLL_INTERVAL = 5_000;
export const FUND_POLL_INTERVAL = 10_000;
export const PROOF_TIMEOUT = 300_000;

// Retry
export const MAX_RETRIES = 3;

// Token precision
export const NIGHT_DECIMALS = 6;
export const DUST_DECIMALS = 15;

// Devnet compose file search order
export const COMPOSE_SEARCH_PATHS = [
	"devnet.yml",
	path.join(".midnight", "devnet.yml"),
];
export const COMPOSE_FALLBACK = path.join(
	process.env["HOME"] ?? "~",
	".midnight-expert",
	"devnet",
	"devnet.yml",
);

// Contract
export const ZK_CONFIG_PATH = "{{CONTRACT_ZK_CONFIG_PATH}}";
export const CONTRACT_NAME = "{{CONTRACT_NAME}}";
