/**
 * Coverage for `XFTY_RecordTypeDataProvider` - one SOQL for the whole
 * transaction, no matter how many SObjects or names are asked for.
 */
@IsTest
private class XFTY_RecordTypeDataProviderTest {

    @IsTest
    static void returnsNullForAnUnknownDeveloperName() {
        Assert.isNull(XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'This_Does_Not_Exist'));
        Assert.isNull(XFTY_RecordTypeDataProvider.idFor(Account.SObjectType, 'This_Does_Not_Exist'));
    }

    @IsTest
    static void returnsNullForANullDeveloperName() {
        Assert.isNull(XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, null));
    }

    @IsTest
    static void queriesOnceForTheWholeTransactionAcrossManySObjectsAndNames() {
        Integer before = Limits.getQueries();

        XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'a');
        XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'b');
        XFTY_RecordTypeDataProvider.getFor(Contact.SObjectType, 'c');
        XFTY_RecordTypeDataProvider.allFor(Opportunity.SObjectType);
        XFTY_RecordTypeDataProvider.idFor(Case.SObjectType, 'd');

        Assert.areEqual(1, Limits.getQueries() - before, 'Exactly one SOQL for the whole repository');
    }

    @IsTest
    static void allForReturnsAnEmptyMapForAnSObjectWithNoRecordTypes() {
        Map<String, RecordType> result = XFTY_RecordTypeDataProvider.allFor(Contact.SObjectType);
        Assert.isNotNull(result);
        Assert.areEqual(0, result.size());
    }
}
