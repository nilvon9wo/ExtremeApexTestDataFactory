/**
 * Coverage for `XFTY_RecordTypeMatching`. Uses the built-in `PersonAccount`
 * Account record type (the scratch org enables Person Accounts) for the
 * "real record type" paths.
 */
@IsTest
private class XFTY_RecordTypeMatchingTest {

    private static Id personRtId() {
        return Account.SObjectType.getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('PersonAccount')
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
                'PersonAccount',
                XFTY_RecordTypeMatching.developerNameOf(new Account(RecordTypeId = personRtId()))
        );
    }

    @IsTest
    static void idForResolvesFromTheDescribe() {
        Assert.isNull(XFTY_RecordTypeMatching.idFor(Account.SObjectType, null), 'null developer name');
        Assert.isNull(XFTY_RecordTypeMatching.idFor(Account.SObjectType, 'NoSuchRecordType'), 'unknown developer name');
        Assert.areEqual(personRtId(), XFTY_RecordTypeMatching.idFor(Account.SObjectType, 'PersonAccount'));
    }

    @IsTest
    static void matchesComparesResolvedDeveloperNames() {
        Assert.isTrue(
                XFTY_RecordTypeMatching.matches(new Account(), Account.SObjectType, null),
                'no record type matches the null name'
        );
        // developer name differs, and the fallback Id comparison also fails
        Assert.isFalse(
                XFTY_RecordTypeMatching.matches(new Account(), Account.SObjectType, 'PersonAccount')
        );
        Assert.isTrue(
                XFTY_RecordTypeMatching.matches(
                        new Account(RecordTypeId = personRtId()), Account.SObjectType, 'PersonAccount'
                )
        );
    }
}
