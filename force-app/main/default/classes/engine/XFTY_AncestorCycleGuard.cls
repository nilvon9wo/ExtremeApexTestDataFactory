/**
 * Tracks the Provider lookup keys currently being generated up the ancestor
 * chain, so `XFTY_AncestorGenerator` can refuse to recurse into one that is
 * already in progress - an infinite `A -> A -> A ...` cycle.
 *
 * Keyed by `XFTY_LookupKeyIntf.getHashKey()` (a `String`), so a deliberate deep
 * hierarchy built with distinct per-level Providers - different keys - is not a
 * cycle and recurses freely.
 *
 * Immutable. Derive a deeper guard with {@link #descendingInto}.
 */
@IsTest
public class XFTY_AncestorCycleGuard {
    private final Boolean cyclesAllowed;
    private final Set<String> providerKeyHashesInProgress;

    public XFTY_AncestorCycleGuard(Boolean cyclesAllowed) {
        this(cyclesAllowed, new Set<String>());
    }

    private XFTY_AncestorCycleGuard(Boolean cyclesAllowed, Set<String> providerKeyHashesInProgress) {
        this.cyclesAllowed = (cyclesAllowed == true);
        this.providerKeyHashesInProgress = providerKeyHashesInProgress;
    }

    /** True when descending into `providerKeyHash` would repeat a key already in progress. */
    public Boolean wouldCycleOn(String providerKeyHash) {
        return !this.cyclesAllowed
                && this.providerKeyHashesInProgress.contains(providerKeyHash);
    }

    /** A guard for one level deeper, with `providerKeyHash` added to the chain. */
    public XFTY_AncestorCycleGuard descendingInto(String providerKeyHash) {
        Set<String> deeper = new Set<String>();
        deeper.addAll(this.providerKeyHashesInProgress);
        deeper.add(providerKeyHash);
        return new XFTY_AncestorCycleGuard(this.cyclesAllowed, deeper);
    }
}
