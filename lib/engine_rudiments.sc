// CroneEngine_Rudiments
// SuperCollider engine for rudiments

Engine_Rudiments : CroneEngine {
	var pg;
	var shape;
	var freq;
	var decay;
	var sweep;
	var lfoFreq;
	var lfoShape;
	var lfoSweep;
	
	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}
	
	alloc {
		pg = ParGroup.tail(context.xg);
		
		shape = Array.fill(8, { 0 });
		freq = Array.fill(8, { 220 });
		decay = Array.fill(8, { 0.2 });
		sweep = Array.fill(8, { 1000 });
		lfoFreq = Array.fill(8, { 60 });
		lfoShape = Array.fill(8, { 0 });
		lfoSweep = Array.fill(8, { 100 });
		
		SynthDef("Rudiments", { arg out, shape, freq, decay, sweep, lfoFreq, lfoShape = lfoShape, lfoSweep;
			// ENV
			var env = EnvGen.kr(Env.perc(0, decay), doneAction: 2);
			
			// LFO
			var lfoSquare = Pulse.ar(lfoFreq);
			var lfoTriangle = LFTri.ar(lfoFreq);
			var lfo = SelectX.ar(lfoShape, [lfoTriangle, lfoSquare]);
			
			// OSC
			var triangle = LFTri.ar(freq + (env * sweep) + (lfo * lfoSweep));
			var square = Pulse.ar(freq + (env * sweep) + (lfo * lfoSweep));
			var osc = SelectX.ar(shape, [triangle, square]);
			
			// AMP
			var final = osc * env;
			
			// OUTPUT
			Out.ar(out, final.dup);
		}).add;
		
		this.addCommand("trigger", "i", { arg msg;
			var i = msg[1];
			
			var shapeVal = shape[i];
			var freqVal = freq[i];
			var decayVal = decay[i];
			var sweepVal = sweep[i];
			var lfoFreqVal = lfoFreq[i];
			var lfoShapeVal = lfoShape[i];
			var lfoSweepVal = lfoSweep[i];
			
			Synth("Rudiments", [\out, context.out_b, \shape, shapeVal, \freq, freqVal, \decay, decayVal, \sweep, sweepVal, \lfoFreq, lfoFreqVal, \lfoShape, lfoShapeVal, \lfoSweep, lfoSweepVal], target:pg);
		});
		
		this.addCommand("shape", "fi", { arg msg;
			shape[msg[2]] = msg[1];
		});
		
		this.addCommand("freq", "fi", { arg msg;
			freq[msg[2]] = msg[1];
		});
		
		this.addCommand("decay", "fi", { arg msg;
			decay[msg[2]] = msg[1];
		});
		
		this.addCommand("sweep", "fi", { arg msg;
			sweep[msg[2]] = msg[1];
		});
		
		this.addCommand("lfoFreq", "fi", { arg msg;
			lfoFreq[msg[2]] = msg[1];
		});
		
		this.addCommand("lfoShape", "fi", { arg msg;
			lfoShape[msg[2]] = msg[1];
		});
		
		this.addCommand("lfoSweep", "fi", { arg msg;
			lfoSweep[msg[2]] = msg[1];
		});
	}
}
