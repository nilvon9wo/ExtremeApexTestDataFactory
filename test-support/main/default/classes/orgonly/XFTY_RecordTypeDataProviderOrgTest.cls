/**
 * Proves `XFTY_RecordTypeDataProvider` does exactly one SOQL for the whole
 * transaction, however many SObjects or names are asked for.
 *
 * In `test-support/orgonly/` because the local Apex runtime resolves record types
 * without a countable query, so `Limits.getQueries()` disagrees with the platform.
 * Passes on a scratch org; `nimbus test` excludes `orgonly/`. The rest of the
 * coverage is in `XFTY_RecordTypeDataProviderTest` (force-app).
 */
@IsTest
private class XFTY_RecordTypeDataProviderOrgTest {

    @IsTest
    static void testGetFor_calledManyTimesAcrossSObjectsAndNames_queriesOnlyOncePerTransaction() {
        // Arrange
        // nothing to arrange

        // Act
        Integer queriesUsed;
        Test.startTest();
        Integer before = Limits.getQueries();
        XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'a');
        XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'b');
        XFTY_RecordTypeDataProvider.getFor(Contact.SObjectType, 'c');
        XFTY_RecordTypeDataProvider.allFor(Opportunity.SObjectType);
        XFTY_RecordTypeDataProvider.idFor(Case.SObjectType, 'd');
        queriesUsed = Limits.getQueries() - before;
        Test.stopTest();

        // Assert
        Assert.areEqual(1, queriesUsed, 'exactly one SOQL for the whole transaction');
    }
}
