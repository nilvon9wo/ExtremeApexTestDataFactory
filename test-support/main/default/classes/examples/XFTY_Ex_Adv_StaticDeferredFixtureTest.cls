/**
 * Runnable proof for docs/use/advanced/deep-setup-chains.md - Form 1 of the
 * `static {}` block fixture: both bundles are built inline (no DML), then a
 * single trailing static initialiser block flushes them once, before any test
 * method runs.
 *
 * Every assertion reads the bundle instances, never `SELECT COUNT()`: the
 * bundle is rebuilt fresh for each test method, so it is immune to the one
 * thing Nimbus cannot reproduce - Salesforce rolling back a test method's
 * static-initialiser DML. That cross-method database isolation is a Salesforce
 * guarantee (docs/reference/salesforce-considerations.md), not XFTY behaviour.
 */
@IsTest
private class XFTY_Ex_Adv_StaticDeferredFixtureTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    private static XFTY_DummySObjectBundle sharedAccounts = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
            .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
            .setQuantityPerTemplate(3)
            .supplyBundle();

    private static XFTY_DummySObjectBundle sharedContacts = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
            .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
            .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
            .setQuantityPerTemplate(2)
            .supplyBundle();

    static {
        XFTY_DeferredInserter.flush();   // one insert phase for both, before any test method runs
    }

    @IsTest
    static void testStaticBlock_flushesTheAccountFixture() {
        // Arrange
        // nothing to arrange - the static block already flushed sharedAccounts

        // Act
        List<Account> flushedAccounts = sharedAccounts.getList(Account.Id);

        // Assert
        Assert.areEqual(3, flushedAccounts.size());
        Assert.isNotNull(flushedAccounts[0].Id, 'flush() in the static block back-filled the Ids onto the bundle');
    }

    @IsTest
    static void testStaticBlock_alsoFlushesTheContactFixtureAndWiresItsParents() {
        // Arrange
        // nothing to arrange - the same static block flushed sharedContacts too

        // Act
        List<Contact> flushedContacts = sharedContacts.getList(Contact.Id);

        // Assert
        Assert.areEqual(2, flushedContacts.size());
        Assert.isNotNull(flushedContacts[0].Id, 'the one flush covered both bundles');
        Assert.isNotNull(flushedContacts[0].AccountId, 'the depth-batched insert wired each Contact to its generated Account');
    }
}
