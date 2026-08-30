/**
 * The DML-backed insert modes of `XFTY_DummySObjectFactory` - `NOW` and
 * `RELATED_ONLY` - split out from `XFTY_DummySObjectFactoryTest` so the unit
 * suite (`XFTY_Unit`) can run without them. This class is in `XFTY_Integration`.
 *
 * The mode/inclusivity matrix that needs no DML stays in
 * `XFTY_DummySObjectFactoryTest`.
 */
@IsTest
private class XFTY_DummySObjectFactoryDmlTest {
    private static final XFTY_DefaultSObjectProviderLookup DEFAULT_LOOKUP = new XFTY_DefaultSObjectProviderLookup();
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void nowInsertsEveryGeneratedRecord() {
        XFTY_DummySObjectBundle bundle = supplyContact(XFTY_InsertModeEnum.NOW);

        Assert.areEqual(1, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(
                bundle.getList(Contact.AccountId)[0].Id,
                [SELECT AccountId FROM Contact LIMIT 1].AccountId
        );
    }

    @IsTest
    static void relatedOnlyInsertsParentsButNotThePrimaryRecords() {
        XFTY_DummySObjectBundle bundle = supplyContact(XFTY_InsertModeEnum.RELATED_ONLY);

        Assert.isNull(bundle.getList(Contact.Id)[0].Id, 'The requested Contact is left uninserted');
        Assert.isNotNull(bundle.getList(Contact.AccountId)[0].Id, 'The related Account is inserted');
        Assert.areEqual(0, [SELECT COUNT() FROM Contact]);
        Assert.areEqual(1, [SELECT COUNT() FROM Account]);
        Assert.areEqual(
                bundle.getList(Contact.AccountId)[0].Id,
                ((Contact) bundle.getList(Contact.Id)[0]).AccountId
        );
    }

    private static XFTY_DummySObjectBundle supplyContact(XFTY_InsertModeEnum insertMode) {
        XFTY_DummySObjectBundle bundle;
        System.runAs(TEST_ADMIN) {
            bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, DEFAULT_LOOKUP)
                    .setOverrideTemplate(new Contact(LastName = 'Factory Test'))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                    .setInsertMode(insertMode)
                    .supplyBundle();
        }
        return bundle;
    }
}
