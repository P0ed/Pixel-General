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
	case "ppo":
		try PPOTrainer.run(Array(arguments.dropFirst()))
	default:
		print("""
		Usage: Train <command> [options]

		  rollout --n <count> [--out <dir>] [--seed <base>]
			 [--suite classic|mixed] [--verify]
			  Generate heuristic-vs-heuristic PGRP-v2 replay files. The default
			  mixed suite rotates open battles and both survival defenders.
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
			 [--suite classic|mixed]
			  Arena: the pure-Swift LSTMPolicy vs the heuristic AI, each config played
			  from both sides; reports both records and gates on 0 illegal actions.
		  rl --weights <pgw> [--out <dir>] [--iters <n>] [--episodes <per iter>]
			 [--b <streams>] [--t <bptt>] [--lr <rate>] [--temp <sampling>]
			 [--seed <battle base>] [--ckpt <every>] [--evaln <configs>]
			 [--curriculum <level 0-3>] [--suite classic|mixed]
			  REINFORCE fine-tune vs the frozen heuristic: sampled episodes,
			  leave-one-out baseline, advantage-weighted CE; arena eval at checkpoints.
			  --curriculum starts collection with the policy seat economically
			  boosted (3 = rich+lvl5+tier3 vs poor) and anneals toward 0 as
			  the sampled win rate clears 35%.
		  ppo [--weights <pgw>] [--ref <pgw>] [--out <dir>] [--iters <n>]
			 [--episodes <per iter>] [--epochs <passes>] [--clip <ε>]
			 [--vcoef <c>] [--kl <β>] [--ent <c>] [--vwarm <iters>] [--lam <λ>]
			 [--b --t --lr --temp --seed --ckpt --evaln --curriculum --anneal --suite]
			  PPO fine-tune: clipped surrogate over --epochs reuses of each
			  episode batch, trained value-head baseline (GAE, γ=1), and a
			  full-distribution KL anchor to --ref (default: the starting
			  weights). --vwarm trains the value head alone first; same
			  collection, reward, and curriculum machinery as rl.
		""")
	}
} catch {
	FileHandle.standardError.write(Data("error: \(error)\n".utf8))
	exit(1)
}
