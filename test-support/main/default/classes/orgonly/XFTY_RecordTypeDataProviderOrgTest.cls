/**
 * `XFTY_RecordTypeDataProvider` does exactly one SOQL for the whole transaction,
 * however many SObjects or names are asked for.
 *
 * In `test-support/orgonly/` because the local Apex runtime resolves record types
 * without a countable query, so `Limits.getQueries()` disagrees with the
 * platform. Passes on a scratch org; the local run excludes `orgonly/`. The rest
 * of the class's coverage is in `XFTY_RecordTypeDataProviderTest` (force-app).
 */
@IsTest
private class XFTY_RecordTypeDataProviderOrgTest {

    @IsTest
    static void queriesOnceForTheWholeTransactionAcrossManySObjectsAndNames() {
        // Arrange
        Integer queriesBefore = Limits.getQueries();

        // Act
        XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'a');
        XFTY_RecordTypeDataProvider.getFor(Account.SObjectType, 'b');
        XFTY_RecordTypeDataProvider.getFor(Contact.SObjectType, 'c');
        XFTY_RecordTypeDataProvider.allFor(Opportunity.SObjectType);
        XFTY_RecordTypeDataProvider.idFor(Case.SObjectType, 'd');

        // Assert
        Assert.areEqual(1, Limits.getQueries() - queriesBefore, 'exactly one SOQL for the whole transaction');
    }
}
