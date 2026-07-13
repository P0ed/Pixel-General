import Foundation
import COR

// Train — headless data-generation / training CLI for the LSTM AI.
// See Docs/AI.md.

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
		      Behavior-clone the heuristic AI from a replay corpus; writes PGW1
		      checkpoints and a CSV loss/accuracy log.
		  eval --weights <pgw> [--n <configs>] [--seed <base>] [--wseed <n>]
		      Arena: the pure-Swift LSTMPolicy vs the heuristic AI, each config played
		      from both sides; reports win rate and gates on 0 illegal actions.
		  rl --weights <pgw> [--out <dir>] [--iters <n>] [--episodes <per iter>]
		     [--b <streams>] [--t <bptt>] [--lr <rate>] [--temp <sampling>]
		     [--seed <battle base>] [--ckpt <every>] [--evaln <configs>]
		     [--curriculum <level 0-3>]
		      REINFORCE fine-tune vs the frozen heuristic: sampled episodes,
		      leave-one-out baseline, advantage-weighted CE; arena eval at checkpoints.
		      --curriculum starts collection with the policy seat economically
		      boosted (3 = rich+lvl5+tier3 vs poor) and anneals toward 0 as
		      the sampled win rate clears 35%.
		""")
	}
} catch {
	FileHandle.standardError.write(Data("error: \(error)\n".utf8))
	exit(1)
}
