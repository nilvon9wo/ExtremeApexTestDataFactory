/**
 * Coverage for `XFTY_RecordTypeDataProvider`, the small helper that maps an
 * SObject + record type developer name to a `RecordType` without repeated SOQL.
 */
@IsTest
private class XFTY_RecordTypeDataProviderTest {

    @IsTest
    static void returnsNullForAnUnknownDeveloperName() {
        Assert.isNull(XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'This_Does_Not_Exist'));
    }

    @IsTest
    static void queriesEachSObjectAtMostOnce() {
        Integer before = Limits.getQueries();
        XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'Alpha');
        Integer afterFirst = Limits.getQueries();
        XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'Beta');
        Integer afterSecond = Limits.getQueries();

        Assert.areEqual(1, afterFirst - before, 'The first lookup for an SObject queries once');
        Assert.areEqual(0, afterSecond - afterFirst, 'A later lookup for the same SObject is served from cache');
    }

    @IsTest
    static void differentSObjectsAreLoadedIndependently() {
        Integer before = Limits.getQueries();
        XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'x');
        XFTY_RecordTypeDataProvider.getFor(Contact.SObjectType, 'x');
        Integer after = Limits.getQueries();

        Assert.areEqual(2, after - before, 'One query per distinct SObject');
    }
}
