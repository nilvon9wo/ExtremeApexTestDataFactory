/**
 * Coverage for `XFTY_RecordTypeMatching`. Uses the `XFTY_TestBusiness` Account
 * record type from `test-support/` for the "real record type" paths.
 */
@IsTest
private class XFTY_RecordTypeMatchingTest {

    private static Id businessRtId() {
        return Account.SObjectType.getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('XFTY_TestBusiness')
                .getRecordTypeId();
    }

    @IsTest
    static void developerNameOfHandlesTheAbsenceOfARecordType() {
        Assert.isNull(XFTY_RecordTypeMatching.developerNameOf(null), 'null record');
        Assert.isNull(XFTY_RecordTypeMatching.developerNameOf(new User()), 'SObject with no RecordTypeId field');
        Assert.isNull(XFTY_RecordTypeMatching.developerNameOf(new Account()), 'record with no RecordTypeId value');
    }

    @IsTest
    static void developerNameOfReturnsNullForAnUnknownRecordTypeId() {
        // A structurally-valid record type Id that is not a real record type on Account.
        Id fabricatedRtId = XFTY_IdMocker.generateId(new RecordType().getSObjectType());
        Assert.isNull(XFTY_RecordTypeMatching.developerNameOf(
                new Account(RecordTypeId = fabricatedRtId)
        ));
    }

    @IsTest
    static void developerNameOfResolvesARealRecordType() {
        Assert.areEqual(
                'XFTY_TestBusiness',
                XFTY_RecordTypeMatching.developerNameOf(new Account(RecordTypeId = businessRtId()))
        );
    }

    @IsTest
    static void idForResolvesFromTheDescribe() {
        Assert.isNull(XFTY_RecordTypeMatching.idFor(Account.SObjectType, null), 'null developer name');
        Assert.isNull(XFTY_RecordTypeMatching.idFor(Account.SObjectType, 'NoSuchRecordType'), 'unknown developer name');
        Assert.areEqual(businessRtId(), XFTY_RecordTypeMatching.idFor(Account.SObjectType, 'XFTY_TestBusiness'));
    }

    @IsTest
    static void matchesComparesResolvedDeveloperNames() {
        Assert.isTrue(XFTY_RecordTypeMatching.matches(new Account(), null), 'no record type matches the null name');
        Assert.isFalse(XFTY_RecordTypeMatching.matches(new Account(), 'XFTY_TestBusiness'));
        Assert.isTrue(XFTY_RecordTypeMatching.matches(
                new Account(RecordTypeId = businessRtId()), 'XFTY_TestBusiness'
        ));
    }
}
