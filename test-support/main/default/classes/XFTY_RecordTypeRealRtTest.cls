/**
 * The "real record type" paths of `XFTY_RecordTypeMatching`,
 * `XFTY_RecordTypeLookupKey`, and `XFTY_FlavouredLookupKey` - the ones that need
 * an actual record type to exist.
 *
 * Lives in `test-support/` (not the published package) because it uses the
 * built-in `PersonAccount` Account record type, which only exists when the org
 * has the Person Accounts feature. The feature-independent paths of the same
 * classes are covered by `XFTY_RecordTypeMatchingTest` / `XFTY_LookupKeyTest` in
 * `force-app`.
 */
@IsTest
private class XFTY_RecordTypeRealRtTest {

    private static final String REAL_RT = 'PersonAccount';

    private static Id realRtId() {
        return Account.SObjectType.getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get(REAL_RT)
                .getRecordTypeId();
    }

    // XFTY_RecordTypeMatching ------------------------------------------------

    @IsTest
    static void developerNameOfResolvesARealRecordType() {
        Assert.areEqual(
                REAL_RT,
                XFTY_RecordTypeMatching.developerNameOf(new Account(RecordTypeId = realRtId()))
        );
    }

    @IsTest
    static void idForResolvesARealRecordTypeFromTheDescribe() {
        Assert.areEqual(realRtId(), XFTY_RecordTypeMatching.idFor(Account.SObjectType, REAL_RT));
    }

    @IsTest
    static void matchesARecordCarryingThatRecordType() {
        Assert.isTrue(
                XFTY_RecordTypeMatching.matches(
                        new Account(RecordTypeId = realRtId()), Account.SObjectType, REAL_RT
                )
        );
    }

    @IsTest
    static void matchesFallsBackToTheIdComparisonWhenDeveloperNamesDiffer() {
        // The record carries an unrecognised record type Id, so developerNameOf(...)
        // returns null and the name check fails - forcing the Id-comparison fallback,
        // which resolves the real Id for REAL_RT and finds it does not match.
        Id staleRtId = XFTY_IdMocker.generateId(new RecordType().getSObjectType());
        Assert.isFalse(
                XFTY_RecordTypeMatching.matches(
                        new Account(RecordTypeId = staleRtId), Account.SObjectType, REAL_RT
                )
        );
    }

    // XFTY_RecordTypeLookupKey / XFTY_FlavouredLookupKey ---------------------

    @IsTest
    static void recordTypeKeyResolvesItsRecordTypeId() {
        Assert.areEqual(
                realRtId(),
                XFTY_RecordTypeLookupKey.get(Account.SObjectType, REAL_RT).getRecordTypeId()
        );
    }

    @IsTest
    static void flavouredKeyResolvesItsRecordTypeIdAndMatchesOnIt() {
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(Account.SObjectType, REAL_RT, 'vip')
                .matching(XFTY_FieldPredicate.isNotNull(Account.LastName));

        Assert.areEqual('vip', key.getFlavour());
        Assert.areEqual(REAL_RT, key.getRecordTypeDeveloperName());
        Assert.areEqual(realRtId(), key.getRecordTypeId());
        Assert.isTrue(key.isInstanceOf(new Account(RecordTypeId = realRtId(), LastName = 'Doe')));
        Assert.isFalse(key.isInstanceOf(new Account(LastName = 'Doe')), 'wrong record type');
    }
}
