/**
 * Coverage for `XFTY_AncestorCycleGuard` - the key-chain tracking that stops an
 * infinite `A -> A -> A ...` ancestor cycle.
 */
@IsTest
private class XFTY_AncestorCycleGuardTest {

    @IsTest
    static void anEmptyGuardNeverCycles() {
        XFTY_AncestorCycleGuard guard = new XFTY_AncestorCycleGuard(false);

        Assert.isFalse(guard.wouldCycleOn('Account'));
    }

    @IsTest
    static void aKeyAlreadyInProgressCycles() {
        XFTY_AncestorCycleGuard guard = new XFTY_AncestorCycleGuard(false)
                .descendingInto('Account');

        Assert.isTrue(guard.wouldCycleOn('Account'), 'the same key one level up is a cycle');
        Assert.isFalse(guard.wouldCycleOn('Contact'), 'a different key is not');
    }

    @IsTest
    static void descendingIntoAccumulatesAndDoesNotMutateTheParent() {
        XFTY_AncestorCycleGuard parent = new XFTY_AncestorCycleGuard(false)
                .descendingInto('Account');
        XFTY_AncestorCycleGuard child = parent.descendingInto('Contact');

        Assert.isTrue(child.wouldCycleOn('Account'));
        Assert.isTrue(child.wouldCycleOn('Contact'));
        Assert.isFalse(parent.wouldCycleOn('Contact'), 'the parent guard is unchanged');
    }

    @IsTest
    static void cyclesAllowedSuppressesTheCheck() {
        XFTY_AncestorCycleGuard guard = new XFTY_AncestorCycleGuard(true)
                .descendingInto('Account');

        Assert.isFalse(guard.wouldCycleOn('Account'), 'allowAncestorCycles() lets the repeat through');
    }
}
