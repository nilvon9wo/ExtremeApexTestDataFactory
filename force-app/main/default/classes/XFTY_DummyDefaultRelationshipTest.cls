/**
 * Coverage for `XFTY_DummyDefaultRelationship`, including deferred + memoised
 * lookup-key resolution.
 */
@IsTest
private class XFTY_DummyDefaultRelationshipTest {

    @IsTest
    static void exposesTheOverrideTemplateAndRelatedField() {
        Account template = new Account(Name = 'Parent');

        XFTY_DummyDefaultRelationship withId = new XFTY_DummyDefaultRelationship(template);
        Assert.areEqual(template, withId.getOverrideTemplate());
        Assert.isNull(withId.getRelatedField());

        XFTY_DummyDefaultRelationship withField =
                new XFTY_DummyDefaultRelationship(template, Account.AccountNumber);
        Assert.areEqual(Account.AccountNumber, withField.getRelatedField());
    }

    @IsTest
    static void anExplicitKeyIsUsedAsIs() {
        XFTY_LookupKeyIntf explicitKey = XFTY_FlavorLookupKey.get(Account.SObjectType, 'big');
        XFTY_DummyDefaultRelationship relationship =
                new XFTY_DummyDefaultRelationship(explicitKey, new Account());

        Assert.areEqual(explicitKey, relationship.resolveLookupKey(new CountingLookup()));
    }

    @IsTest
    static void anAbsentKeyIsDerivedFromTheTemplateOnceAndMemoised() {
        XFTY_DummyDefaultRelationship relationship = new XFTY_DummyDefaultRelationship(new Account());
        CountingLookup lookup = new CountingLookup();

        XFTY_LookupKeyIntf firstCall = relationship.resolveLookupKey(lookup);
        XFTY_LookupKeyIntf secondCall = relationship.resolveLookupKey(lookup);

        Assert.areEqual(1, lookup.keyForCalls, 'Derivation should happen only once');
        Assert.areEqual(firstCall, secondCall, 'The memoised key is returned on later calls');
        Assert.areEqual('Account', firstCall.getHashKey());
    }

    private class CountingLookup implements XFTY_DummySObjectProviderLookupIntf {
        private Integer keyForCalls = 0;

        public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
            return null;
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
            return null;
        }
        public XFTY_LookupKeyIntf keyFor(SObject sObj) {
            this.keyForCalls++;
            return XFTY_LookupKey.get(sObj.getSObjectType());
        }
    }
}
