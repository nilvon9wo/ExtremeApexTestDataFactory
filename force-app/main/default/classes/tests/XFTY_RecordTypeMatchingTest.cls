/**
 * Coverage for `XFTY_RecordTypeMatching` - the paths that do not need any real
 * record type to exist (null / absent / unknown record types), so this runs in
 * any org.
 *
 * The "real record type" paths are covered by `XFTY_RecordTypeRealRtTest` in
 * `test-support/` (it uses the built-in `PersonAccount` record type, which the
 * published package must not require).
 */
@IsTest
private class XFTY_RecordTypeMatchingTest {

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
    static void idForReturnsNullForNullAndUnknownDeveloperNames() {
        Assert.isNull(XFTY_RecordTypeMatching.idFor(Account.SObjectType, null), 'null developer name');
        Assert.isNull(XFTY_RecordTypeMatching.idFor(Account.SObjectType, 'NoSuchRecordType'), 'unknown developer name');
    }

    @IsTest
    static void matchesTreatsANullNameAsNoRecordType() {
        Assert.isTrue(
                XFTY_RecordTypeMatching.matches(new Account(), Account.SObjectType, null),
                'no record type matches the null name'
        );
    }

    @IsTest
    static void matchesReturnsFalseWhenTheNamedRecordTypeIsAbsentOrDiffers() {
        // Developer name differs from the record's (null), and the fallback Id
        // comparison also fails (no such record type, or the record has none).
        Assert.isFalse(
                XFTY_RecordTypeMatching.matches(new Account(), Account.SObjectType, 'NoSuchRecordType')
        );
        Id fabricatedRtId = XFTY_IdMocker.generateId(new RecordType().getSObjectType());
        Assert.isFalse(
                XFTY_RecordTypeMatching.matches(
                        new Account(RecordTypeId = fabricatedRtId), Account.SObjectType, 'NoSuchRecordType'
                )
        );
    }

    @IsTest
    static void matchesRunsTheIdFallbackWhenTheNameResolvesButTheRecordDiffers() {
        // 'Master' resolves to the placeholder master record-type Id on every
        // SObject in every org, so idFor(...) returns non-null here and the
        // fallback Id comparison actually executes - then fails, because the
        // record carries no RecordTypeId. (Real-record-type coverage of the same
        // fallback is in test-support/XFTY_RecordTypeRealRtTest.)
        Assert.isFalse(
                XFTY_RecordTypeMatching.matches(new Account(), Account.SObjectType, 'Master')
        );
    }
}
