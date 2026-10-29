# Trust design

The following is the author's specification, preserved verbatim. It is a design direction; the current implementation still uses a single peer trust value.

```text
credibility: of user credibility such as suspicious or highly disruptive desyncs
reliability: of network integrity

so swarm trust accumulation only involves credibility
reliability is determined locally

trust is dot of the 2, calculated different where relevant

position syncs are .9 reliab .1 cred
self-recieved-hits and ammo (incl missiles) are .8 cred .2 rliab
other-inflicted-hits are .5 reliab .5 cred

cred is lost from desyncs of: offensive hits, ammo, hp;
where loss increases parab, such that a few desyncs have little effect.
cred-decred max change rate is .1%/sec
```

## Historical formulas (verbatim)

```text
decred-=  clap01(.05*dt); //each decred lasts 20sec
cred-= decred*decred *dt *.001;
//cred slowly increases constantly sqrtly:
cred= sqrt(cred+.001dt) sq
```

TODO: save credibility persistently in a local player database.

Author clarification: recovery is `cred = sqrt(cred sq + .001*dt)`;
clamp credibility and decred to [0,1] when changed. Recovery is intended
to be faster at low credibility. The 0.1%/s credibility change limit applies
in both directions. The formula above is retained verbatim as originally given;
this clarification was subsequently replaced by the accepted linear recovery below.


## Accepted evolution

`c01` clamps to [0,1]. `dt` is elapsed seconds; `sev` is a locally
assessed amount per qualifying desync. The discrepancy already incorporates
its packet interval, so severity is not multiplied by dt again.
`disc` is the same transient penalty previously called `decred`.

```nim
disc = c01(disc + sev)        # on a qualifying desync; no extra dt
                            # todo: severity for packet-independent values such as ammo

disc = c01(disc - .05*dt)     # once per update; full discredit fades over 20s

recovery = (1 - cred) * .001
penalty  = disc*disc * .001
cred = c01(cred + (recovery - penalty)*dt)
```

Equivalent combined credibility update:

```nim
cred = c01(cred + (1 - cred - disc*disc)*.001*dt)
```

Recovery slows as credibility approaches 1. The penalty is quadratic in
discredit. Because recovery and penalty each lie in [0,.001], the net
credibility rate automatically lies in [-.001,.001] per second. No separate
rate limiter or square-root recovery is needed. Fractional discredit fades
in proportionally less than 20 seconds; 20s applies to a full value of 1.
Time integration is a clamped Euler step, assuming the usual dt below 1s.

## Local reliability

The author's ping/reliability points (milliseconds):

```text
30 ping 1. reliability, 80 ping .8 rel, 150ping .5 rel, 400ping  .05 reliability
```

Use linear interpolation between adjacent points, 1 below 30ms and .05 above
400ms. This is a locally calculated baseline, never a swarm recommendation.
It defines the ping contribution; additional effects of jitter and loss, and
handling unknown measurements, are not yet specified.

Pending policy: calibrate desync severity amounts. Packet-independent discrepancies
such as ammo need their own severity rule, retained as an inline TODO above and
at the reporting hook.


## Credibility databases and dissemination

Each client keeps three local databases:

| File | Influence | Evidence |
|---|---:|---|
| trusts_witnessed.toml | .4 | personally calculated from received packets |
| trusts_paragon.toml | .4 | reports received from paragons |
| trusts_swarm.toml | .2 | reports received from all other peers |

For a subject with all three components available:

    credibility = .4*witnessed + .4*paragon + .2*swarm

These components concern credibility. Network reliability remains locally
measured and does not accumulate through recommendations.

On first connection, peers share their complete witnessed database. Thereafter,
witnessed records are sprayed/fountained like other datakinds. A client's local
witnessed opinion becomes a remote swarm opinion, or a paragon opinion if the
recipient classifies that source as a paragon. Received opinions do not become
personally witnessed evidence. The outgoing data is the local witnessed database,
not a rebroadcast of the client's combined credibility estimate.

The earlier recommendation expression remains the design basis for weighing an
informant's opinion: local credibility of A times A's witnessed credibility of B.
The .4/.4/.2 coefficients describe the three database influences; aggregation
inside the two remote-evidence categories must retain the original informant so
repeated updates replace an opinion instead of counting as additional votes.

Still to specify: treatment of missing database entries and how a client designates
paragons. Persistence and dissemination of these databases are not implemented yet.

## Other and swarm

An other is one peer in the context of a communication or connection; the
swarm is all other peers collectively. An other's contribution about a subject
is the other's combined credibility multiplied by their reported credibility
for that subject. Average contributions within the relevant category. Local
reliability is separate from this calculation.

Zero is the peer initializer; the database sets new accounts to .5.
