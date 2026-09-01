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

    // "exactly one SOQL for the whole transaction" is asserted in
    // XFTY_RecordTypeDataProviderOrgTest (test-support/orgonly) - the local Apex
    // runtime resolves record types without a countable query.

    @IsTest
    static void allForReturnsAnEmptyMapForAnSObjectWithNoRecordTypes() {
        Map<String, RecordType> result = XFTY_RecordTypeDataProvider.allFor(Contact.SObjectType);
        Assert.isNotNull(result);
        Assert.areEqual(0, result.size());
    }
}
