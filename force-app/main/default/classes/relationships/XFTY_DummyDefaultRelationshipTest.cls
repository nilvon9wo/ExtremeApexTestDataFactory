/**
 * Proves `XFTY_DummyDefaultRelationship` - its accessors and its deferred,
 * memoised lookup-key resolution. Pure in-memory, no DML/SOQL.
 */
@IsTest
private class XFTY_DummyDefaultRelationshipTest {

    @IsTest
    static void testGetOverrideTemplate_returnsTheTemplateItWasBuiltWith() {
        // Arrange
        Account template = new Account(Name = 'Parent');

        // Act
        Test.startTest();
        XFTY_DummyDefaultRelationship relationship = new XFTY_DummyDefaultRelationship(template);
        Test.stopTest();

        // Assert
        Assert.areEqual(template, relationship.getOverrideTemplate());
        Assert.isNull(relationship.getRelatedField(), 'no related field was supplied');
    }

    @IsTest
    static void testGetRelatedField_whenBuiltWithARelatedField_returnsIt() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        XFTY_DummyDefaultRelationship relationship =
                new XFTY_DummyDefaultRelationship(new Account(Name = 'Parent'), Account.AccountNumber);
        Test.stopTest();

        // Assert
        Assert.areEqual(Account.AccountNumber, relationship.getRelatedField());
    }

    @IsTest
    static void testResolveLookupKey_whenAnExplicitKeyWasGiven_returnsItAsIs() {
        // Arrange
        XFTY_LookupKeyIntf explicitKey = XFTY_FlavouredLookupKey.get(Account.SObjectType, 'big');
        XFTY_DummyDefaultRelationship relationship = new XFTY_DummyDefaultRelationship(explicitKey, new Account());

        // Act
        Test.startTest();
        XFTY_LookupKeyIntf resolved = relationship.resolveLookupKey(new CountingLookup());
        Test.stopTest();

        // Assert
        Assert.areEqual(explicitKey, resolved);
    }

    @IsTest
    static void testResolveLookupKey_whenNoKeyWasGiven_derivesItFromTheTemplateOnceAndMemoises() {
        // Arrange
        XFTY_DummyDefaultRelationship relationship = new XFTY_DummyDefaultRelationship(new Account());
        CountingLookup lookup = new CountingLookup();

        // Act
        Test.startTest();
        XFTY_LookupKeyIntf firstCall = relationship.resolveLookupKey(lookup);
        XFTY_LookupKeyIntf secondCall = relationship.resolveLookupKey(lookup);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, lookup.keysForCalls, 'derivation happens only once');
        Assert.areEqual(firstCall, secondCall, 'the memoised key is returned on later calls');
        Assert.areEqual('Account', firstCall.getHashKey());
    }

    private class CountingLookup implements XFTY_DummySObjectProviderLookupIntf {
        private Integer keysForCalls = 0;

        public XFTY_DummySobjectProviderIntf get(SObjectType sObjectType) {
            return null;
        }
        public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey) {
            return null;
        }
        public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj) {
            this.keysForCalls++;
            return new Set<XFTY_LookupKeyIntf>();
        }
    }
}
