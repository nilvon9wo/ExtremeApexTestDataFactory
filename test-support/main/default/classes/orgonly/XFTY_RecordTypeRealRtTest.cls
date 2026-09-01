/**
 * The "real record type" paths of `XFTY_RecordTypeMatching`,
 * `XFTY_RecordTypeLookupKey`, and `XFTY_FlavouredLookupKey` - the ones that need
 * an actual record type to exist.
 *
 * Lives in `test-support/orgonly/` because it uses `XFTY_HierarchyNode__c` and
 * its `Root` record type - real record-type metadata the local Apex runtime does
 * not carry. Runs on a scratch org. The feature-independent paths of the same
 * classes are covered by `XFTY_RecordTypeMatchingTest` / `XFTY_LookupKeyTest` in
 * `force-app`.
 */
@IsTest
private class XFTY_RecordTypeRealRtTest {

    private static final SObjectType RT_OBJECT = XFTY_HierarchyNode__c.SObjectType;
    private static final String REAL_RT = 'Root';

    private static Id realRtId() {
        return RT_OBJECT.getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get(REAL_RT)
                .getRecordTypeId();
    }

    // XFTY_RecordTypeMatching ------------------------------------------------

    @IsTest
    static void developerNameOfResolvesARealRecordType() {
        Assert.areEqual(
                REAL_RT,
                XFTY_RecordTypeMatching.developerNameOf(new XFTY_HierarchyNode__c(RecordTypeId = realRtId()))
        );
    }

    @IsTest
    static void idForResolvesARealRecordTypeFromTheDescribe() {
        Assert.areEqual(realRtId(), XFTY_RecordTypeMatching.idFor(RT_OBJECT, REAL_RT));
    }

    @IsTest
    static void matchesARecordCarryingThatRecordType() {
        Assert.isTrue(
                XFTY_RecordTypeMatching.matches(
                        new XFTY_HierarchyNode__c(RecordTypeId = realRtId()), RT_OBJECT, REAL_RT
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
                        new XFTY_HierarchyNode__c(RecordTypeId = staleRtId), RT_OBJECT, REAL_RT
                )
        );
    }

    // XFTY_RecordTypeLookupKey / XFTY_FlavouredLookupKey ---------------------

    @IsTest
    static void recordTypeKeyResolvesItsRecordTypeId() {
        Assert.areEqual(
                realRtId(),
                XFTY_RecordTypeLookupKey.get(RT_OBJECT, REAL_RT).getRecordTypeId()
        );
    }

    @IsTest
    static void flavouredKeyResolvesItsRecordTypeIdAndMatchesOnIt() {
        XFTY_FlavouredLookupKey key = XFTY_FlavouredLookupKey.get(RT_OBJECT, REAL_RT, 'vip')
                .matching(XFTY_FieldPredicate.isNotNull(XFTY_HierarchyNode__c.Name));

        Assert.areEqual('vip', key.getFlavour());
        Assert.areEqual(REAL_RT, key.getRecordTypeDeveloperName());
        Assert.areEqual(realRtId(), key.getRecordTypeId());
        Assert.isTrue(key.isInstanceOf(new XFTY_HierarchyNode__c(RecordTypeId = realRtId(), Name = 'Doe')));
        Assert.isFalse(key.isInstanceOf(new XFTY_HierarchyNode__c(Name = 'Doe')), 'wrong record type');
    }
}
