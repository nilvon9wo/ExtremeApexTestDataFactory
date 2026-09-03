/**
 * Proves `XFTY_EnrichmentTarget` - resolving the `inject(field, ...)` field to
 * the records, sub-bundle and generated-ancestor flag. Pure in-memory.
 */
@IsTest
private class XFTY_EnrichmentTargetTest {

    @IsTest
    static void testLocate_forThePrimaryField_returnsThePrimariesAndTheBundleItself() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact() });

        // Act
        Test.startTest();
        XFTY_EnrichmentTarget target = XFTY_EnrichmentTarget.locate(bundle, Contact.Id);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, target.records.size());
        Assert.isFalse(target.isGeneratedAncestor);
    }

    @IsTest
    static void testLocate_forAGeneratedAncestorField_flagsItAsAnAncestor() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact() });
        bundle.put(Contact.AccountId, new List<SObject>{ new Account() });
        bundle.put(Contact.AccountId, new XFTY_DummySObjectBundle());

        // Act
        Test.startTest();
        XFTY_EnrichmentTarget target = XFTY_EnrichmentTarget.locate(bundle, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.isTrue(target.isGeneratedAncestor);
    }

    @IsTest
    static void testLocate_forAChildField_returnsTheChildList() {
        // Arrange
        XFTY_DummySObjectBundle childBundle = new XFTY_DummySObjectBundle();
        childBundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact(), new Contact() });
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Account.Id, new List<SObject>{ new Account() });
        bundle.putChild(Contact.AccountId, childBundle, new List<Integer>{ 0, 0 });

        // Act
        Test.startTest();
        XFTY_EnrichmentTarget target = XFTY_EnrichmentTarget.locate(bundle, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual(2, target.records.size());
        Assert.isFalse(target.isGeneratedAncestor);
    }

    @IsTest
    static void testLocate_forAnUnknownField_throws() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact() });

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_EnrichmentTarget.locate(bundle, Account.Name);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
    }

    @IsTest
    static void testHasAnythingToInject_whenThereAreNoAncestorsNorChildren_isFalse() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact() });

        // Act
        Test.startTest();
        Boolean anything = XFTY_EnrichmentTarget.locate(bundle, Contact.Id).hasAnythingToInject();
        Test.stopTest();

        // Assert
        Assert.isFalse(anything);
    }

    @IsTest
    static void testHasAnythingToInject_whenThereIsAGeneratedAncestor_isTrue() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact() });
        bundle.put(Contact.AccountId, new XFTY_DummySObjectBundle());

        // Act
        Test.startTest();
        Boolean anything = XFTY_EnrichmentTarget.locate(bundle, Contact.Id).hasAnythingToInject();
        Test.stopTest();

        // Assert
        Assert.isTrue(anything);
    }
}
