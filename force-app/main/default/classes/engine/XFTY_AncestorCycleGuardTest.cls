/**
 * Proves `XFTY_AncestorCycleGuard` - the key-chain tracking that stops an
 * infinite `A -> A -> A ...` ancestor cycle. Pure in-memory state, no DML/SOQL.
 */
@IsTest
private class XFTY_AncestorCycleGuardTest {

    @IsTest
    static void testWouldCycleOn_forAnEmptyGuard_returnsFalse() {
        // Arrange
        XFTY_AncestorCycleGuard guard = new XFTY_AncestorCycleGuard(false);

        // Act
        Test.startTest();
        Boolean cycles = guard.wouldCycleOn('Account');
        Test.stopTest();

        // Assert
        Assert.isFalse(cycles);
    }

    @IsTest
    static void testWouldCycleOn_whenTheKeyIsAlreadyInProgress_returnsTrue() {
        // Arrange
        XFTY_AncestorCycleGuard guard = new XFTY_AncestorCycleGuard(false).descendingInto('Account');

        // Act
        Test.startTest();
        Boolean cycles = guard.wouldCycleOn('Account');
        Test.stopTest();

        // Assert
        Assert.isTrue(cycles, 'the same key one level up is a cycle');
    }

    @IsTest
    static void testWouldCycleOn_forADifferentKeyThanThoseInProgress_returnsFalse() {
        // Arrange
        XFTY_AncestorCycleGuard guard = new XFTY_AncestorCycleGuard(false).descendingInto('Account');

        // Act
        Test.startTest();
        Boolean cycles = guard.wouldCycleOn('Contact');
        Test.stopTest();

        // Assert
        Assert.isFalse(cycles);
    }

    @IsTest
    static void testDescendingInto_accumulatesTheKeyChain() {
        // Arrange
        XFTY_AncestorCycleGuard parent = new XFTY_AncestorCycleGuard(false).descendingInto('Account');

        // Act
        Test.startTest();
        XFTY_AncestorCycleGuard child = parent.descendingInto('Contact');
        Test.stopTest();

        // Assert
        Assert.isTrue(child.wouldCycleOn('Account'));
        Assert.isTrue(child.wouldCycleOn('Contact'));
    }

    @IsTest
    static void testDescendingInto_doesNotMutateTheParentGuard() {
        // Arrange
        XFTY_AncestorCycleGuard parent = new XFTY_AncestorCycleGuard(false).descendingInto('Account');

        // Act
        Test.startTest();
        parent.descendingInto('Contact');
        Test.stopTest();

        // Assert
        Assert.isFalse(parent.wouldCycleOn('Contact'), 'the parent guard is unchanged');
    }

    @IsTest
    static void testWouldCycleOn_whenCyclesAreAllowed_returnsFalseEvenForAKeyInProgress() {
        // Arrange
        XFTY_AncestorCycleGuard guard = new XFTY_AncestorCycleGuard(true).descendingInto('Account');

        // Act
        Test.startTest();
        Boolean cycles = guard.wouldCycleOn('Account');
        Test.stopTest();

        // Assert
        Assert.isFalse(cycles, 'allowAncestorCycles() lets the repeat through');
    }
}
