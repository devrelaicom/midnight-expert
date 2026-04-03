# midnight-mcp

<p align="center">
  <img src="assets/mascot.png" alt="midnight-mcp mascot" width="200" />
</p>

Skills for effective use of the Midnight MCP server -- search strategies, contract analysis and compilation workflows, simulation, repository access, and troubleshooting.

## Skills

### midnight-mcp:mcp-search

Search techniques and tool guidance for the four Midnight MCP search tools (midnight-search-compact, midnight-search-typescript, midnight-search-docs, midnight-fetch-docs). Provides a technique library for query optimization, reranking, and result refinement.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| code-search.md | Techniques for searching code patterns in Compact and TypeScript | Searching for specific code constructs or API usage |
| context-gathering.md | Techniques for enriching queries with conversation or project context | Improving query quality using available context |
| iterative-search.md | Techniques for refining when initial results are insufficient | Running follow-up searches after poor initial results |
| query-expansion.md | Techniques for transforming raw intent into better search input | Preparing queries before calling MCP search tools |
| result-refinement.md | Client-side reasoning techniques for processing search results | Filtering, reranking, or deduplicating returned results |
| server-enhanced.md | Techniques requiring MCP server changes (not yet available) | Understanding current search limitations |
| tool-routing.md | Techniques for selecting and configuring MCP tools before searching | Choosing which search tool to use for a given task |

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| answerability-scoring.md | Scoring whether results can answer the original question | Evaluating search result quality |
| confidence-assessment.md | Assessing confidence in search results | Determining reliability of findings |
| contradiction-detection.md | Detecting contradictions across search results | Identifying conflicting information |
| conversation-grounding.md | Grounding searches in conversation context | Leveraging prior conversation for better queries |
| coverage-balancing.md | Balancing coverage across multiple sources | Ensuring comprehensive search results |
| cross-tool-orchestration.md | Coordinating multiple MCP tools in sequence | Complex searches requiring multiple tool calls |
| decomposition.md | Breaking complex queries into sub-queries | Handling multi-faceted search requests |
| deduplication.md | Removing duplicate results across searches | Cleaning up redundant results |
| diff-aware-search.md | Searching with awareness of code changes | Finding documentation relevant to recent changes |
| entity-extraction.md | Extracting and normalizing entities from queries | Identifying key terms for search |
| environmental-grounding.md | Using project environment info to improve searches | Incorporating version and config context |
| error-to-doc.md | Converting error messages to documentation searches | Finding docs for specific error messages |
| example-mining.md | Finding relevant code examples | Searching for usage examples |
| facet-extraction.md | Extracting search facets from queries | Breaking queries into searchable dimensions |
| freshness-reranking.md | Reranking results by freshness | Prioritizing recent or version-current results |
| hyde.md | Pseudo-answer generation for improved retrieval | Generating hypothetical answers to improve search |
| intent-classification.md | Classifying search intent to route queries | Determining what kind of search to perform |
| multi-query.md | Generating multiple query variants | Improving recall through query diversification |
| parameter-optimization.md | Optimizing search tool parameters | Tuning search parameters for better results |
| query-refinement.md | Iteratively refining queries based on results | Improving queries after seeing initial results |
| query-rewriting.md | Rewriting queries for better tool compatibility | Adapting natural language to search syntax |
| relevance-reranking.md | Reranking results by relevance to the original question | Improving precision of returned results |
| retrieve-read-retrieve.md | Read results then search again with new knowledge | Multi-pass retrieval for deeper understanding |
| source-routing.md | Routing queries to the appropriate search corpus | Selecting compact, typescript, or docs search |
| step-back-queries.md | Generating broader queries to find context | Finding background information for specific questions |
| symbol-aware-search.md | Searching with awareness of code symbols | Finding definitions and usages of specific symbols |
| trust-aware-reranking.md | Reranking by source trustworthiness | Prioritizing results from authoritative sources |
| trusted-source-filtering.md | Filtering results to trusted sources only | Restricting results to official repositories |
| version-aware-search.md | Searching with version awareness | Finding version-specific documentation or code |

### midnight-mcp:mcp-compile

Compile Compact contracts using the hosted compiler service via MCP tools. Supports single-file and multi-file compilation, snippet auto-wrapping, multi-version testing, and OpenZeppelin library linking.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| archive-compilation.md | Compiling multi-file projects as archives | Projects with multiple Compact source files |
| error-recovery.md | Recovering from compilation errors | Diagnosing and fixing compile failures |
| full-compilation.md | Full ZK compilation with proof key generation | Producing complete compilation artifacts |
| multi-version.md | Testing across multiple compiler versions | Checking backwards compatibility |
| quick-validation.md | Fast syntax and type checking without full compilation | Quick validation that code compiles |
| snippet-compilation.md | Compiling code snippets with auto-wrapping | Testing small code fragments |

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| common-patterns.md | Common compilation invocation patterns | Typical compilation workflows |
| disclosure-errors.md | Disclosure-related compilation errors | Debugging privacy boundary violations |
| overflow-errors.md | Arithmetic overflow compilation errors | Debugging numeric overflow issues |
| parse-errors.md | Parse error examples | Debugging syntax errors |
| service-errors.md | MCP service error examples | Diagnosing server-side compilation failures |
| type-errors.md | Type error examples | Debugging type system violations |

### midnight-mcp:mcp-analyze

Four tools for analyzing, visualizing, proving, and diffing Compact contracts. Produces structural analysis, circuit visualizations, proof generation, and semantic diffs between contract versions.

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| tool-invocations.md | Example invocations for all four analysis tools | Reference for correct tool parameters and usage |

### midnight-mcp:mcp-simulate

Four tools providing a real execution environment for deploying and testing Compact contracts without a live network. Uses the OpenZeppelin Compact Simulator for circuit execution with full state management.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| argument-formats.md | Data structures and type mappings for simulation tool parameters | Formatting constructorArgs and circuit arguments |
| caller-context.md | Simulating different callers for access control testing | Testing contracts with multiple user identities |
| circuit-execution.md | Calling circuits and interpreting results | Executing contract functions in simulation |
| deploy-workflows.md | Deploying contracts in simulation sessions | Setting up contracts for testing |
| error-recovery.md | Recovering from simulation errors | Diagnosing deployment or execution failures |
| server-enhanced.md | Planned server-side simulation capabilities (not yet available) | Understanding current simulation limitations |
| session-management.md | Creating and managing simulation sessions | Lifecycle management of simulation environments |
| state-inspection.md | Reading ledger state from simulated contracts | Verifying contract state after operations |
| testing-patterns.md | Patterns for structured contract testing | Designing effective simulation test sequences |
| witness-management.md | Providing and overriding witness values in simulation | Testing contracts with custom witness data |

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| access-control-contract.md | Access control contract archetype with simulation steps | Testing owner-only or role-based contracts |
| assertion-testing.md | Testing contract assertions in simulation | Verifying assertion behavior |
| capacity-errors.md | Rate limit and capacity error examples | Diagnosing server-side resource limits |
| counter-contract.md | Counter contract archetype with simulation steps | Basic contract deployment and state testing |
| deployment-errors.md | Deployment error examples | Debugging contract deployment failures |
| execution-errors.md | Circuit execution error examples | Debugging runtime execution failures |
| multi-user-testing.md | Testing with multiple simulated users | Multi-party contract interaction testing |
| sequential-testing.md | Sequential operation testing patterns | Testing ordered sequences of contract calls |
| session-errors.md | Session management error examples | Debugging session lifecycle issues |
| state-verification.md | State inspection and verification examples | Confirming ledger state matches expectations |
| token-contract.md | Token contract archetype with simulation steps | Testing token minting, transfer, and balance |
| voting-contract.md | Voting contract archetype with simulation steps | Testing voting and governance contracts |
| witness-errors.md | Witness-related error examples | Debugging witness provision failures |

### midnight-mcp:mcp-format

Format Compact code using the hosted midnight-format-contract MCP tool. Preferred over local `compact format` because it requires no disk writes and supports version-specific formatting.

### midnight-mcp:mcp-health

Six tools for checking MCP server health, monitoring rate limits, managing versions, and listing available compilers and libraries. Covers diagnostics, update instructions, and cache statistics.

### midnight-mcp:mcp-overview

Overview of all 32 Midnight MCP tools across 8 categories (Search, Analyze, Format, Diff, Simulate, Repository, Health, Meta) with intent-to-tool routing and token optimization guidance.

### midnight-mcp:mcp-repository

Six individual tools and two compound tools for accessing Midnight repository content, browsing examples, tracking updates, managing version transitions, and checking for breaking changes.

## Commands

### midnight-mcp:search

Search Midnight code, documentation, and SDK patterns with technique-aware query optimization, preset modes, and interactive guided search.

#### Output

Search results from the Midnight MCP search tools, filtered and refined using the selected techniques and presets. Supports compact, typescript, docs, or all-source searches.

#### Invokes

- midnight-mcp:mcp-search (skill)

### midnight-mcp:simulate

Simulate Compact contracts interactively -- deploy, call circuits, inspect state, and verify behavior with preset testing modes and witness/caller control.

#### Output

Simulation session results including deployment status, circuit call outputs, ledger state snapshots, and assertion results. Sessions can be explored interactively or run as automated test sequences.

#### Invokes

- midnight-mcp:mcp-simulate (skill)
- midnight-mcp:mcp-compile (skill, when --compile-first is used)
