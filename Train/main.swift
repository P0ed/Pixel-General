import Foundation

// Train — headless data-generation / training CLI for the LSTM AI.
// Compiles the COR sources directly (a macOS tool cannot link the Catalyst
// framework), so internal core symbols are visible without `@testable`.
// See Docs/LSTM-AI-Plan.md.

// Line-buffer stdout even when redirected to a file, so long runs
// (`Train rl … > run.log`) can be tailed and nothing is lost on a kill.
unsafe setvbuf(stdout, nil, _IOLBF, 0)

let arguments = Array(CommandLine.arguments.dropFirst())

do {
	switch arguments.first {
	case "rollout":
		try Rollouts.run(Array(arguments.dropFirst()))
	case "replay":
		try Replay.inspect(Array(arguments.dropFirst()))
	case "parity":
		try Parity.run(Array(arguments.dropFirst()))
	case "bc":
		try BCTrainer.run(Array(arguments.dropFirst()))
	case "eval":
		try Eval.run(Array(arguments.dropFirst()))
	case "rl":
		try RLTrainer.run(Array(arguments.dropFirst()))
	default:
		print("""
		Usage: Train <command> [options]

		  rollout --n <count> [--out <dir>] [--seed <base>] [--verify]
		      Generate heuristic-vs-heuristic battles as .pgr replay files.
		  replay <file> ...
		      Rebuild replays deterministically and check they reproduce
		      the recorded outcome.
		  parity [--steps <n>] [--seed <battle>] [--wseed <weights>]
		      Compare the MPSGraph model against the pure-Swift LSTMPolicy
		      on live battle steps; gates on max |Δlogit| and argmax flips.
		  bc [--data <dir>] [--out <dir>] [--steps <n>] [--b <streams>]
		     [--t <bptt>] [--lr <rate>] [--holdout <nth>] [--ckpt <every>]
		     [--resume <pgw>]
		      Behavior-clone axisAI from a replay corpus; writes PGW1
		      checkpoints and a CSV loss/accuracy log.
		  eval --weights <pgw> [--n <configs>] [--seed <base>] [--wseed <n>]
		      Arena: the pure-Swift LSTMPolicy vs axisAI, each config played
		      from both sides; reports win rate and gates on 0 illegal actions.
		  rl --weights <pgw> [--out <dir>] [--iters <n>] [--episodes <per iter>]
		     [--b <streams>] [--t <bptt>] [--lr <rate>] [--temp <sampling>]
		     [--seed <battle base>] [--ckpt <every>] [--evaln <configs>]
		      REINFORCE fine-tune vs the frozen heuristic: sampled episodes,
		      EMA baseline, advantage-weighted CE; arena eval at checkpoints.
		""")
	}
} catch {
	FileHandle.standardError.write(Data("error: \(error)\n".utf8))
	exit(1)
}
