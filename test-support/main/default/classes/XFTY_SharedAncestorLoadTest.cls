/**
 * Shared ancestors at volume: the shared record must cost one insert no matter
 * how many children reference it, and the per-child wiring must stay cheap.
 *
 * `test-support/` only. See docs/reference/volume-and-limits.md.
 */
@IsTest
private class XFTY_SharedAncestorLoadTest {
    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    /**
     * 500 Contacts under one shared Account, NOW: one Account row, 500 Contact
     * rows - and a small, constant number of DML *statements*, not one per child.
     */
    @IsTest
    static void fiveHundredChildrenUnderOneSharedAncestorCostOneParentInsert() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));

        Integer stmtsBefore;
        Integer stmtsAfter;
        Integer rowsBefore;
        Integer rowsAfter;
        System.runAs(TEST_ADMIN) {
            Test.startTest();
            stmtsBefore = Limits.getDmlStatements();
            rowsBefore = Limits.getDmlRows();
            new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                    .setQuantityPerTemplate(500)
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(XFTY_InsertModeEnum.NOW)
                    .supplyList();
            stmtsAfter = Limits.getDmlStatements();
            rowsAfter = Limits.getDmlRows();
            Test.stopTest();
        }

        Assert.areEqual(1, [SELECT COUNT() FROM Account], 'one shared Account, not 500');
        Assert.areEqual(500, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(501, rowsAfter - rowsBefore, '1 Account row + 500 Contact rows');
        Assert.isTrue(
                stmtsAfter - stmtsBefore <= 4,
                'a handful of DML statements for 500 shared-ancestor children, used ' + (stmtsAfter - stmtsBefore)
        );
    }

    /**
     * The same shared ancestor referenced from three separate `supply*()` calls
     * still resolves once - one Account row across all three.
     */
    @IsTest
    static void oneSharedAncestorAcrossManySupplyCallsResolvesOnce() {
        XFTY_SharedAncestor.get('hq').of(new Account(Name = 'Shared HQ'));

        System.runAs(TEST_ADMIN) {
            Test.startTest();
            for (Integer call = 0; call < 3; call++) {
                new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
                        .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('hq'))
                        .setQuantityPerTemplate(100)
                        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                        .setInsertMode(XFTY_InsertModeEnum.NOW)
                        .supplyList();
            }
            Test.stopTest();
        }

        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(300, [SELECT COUNT() FROM Contact]);
    }
}
