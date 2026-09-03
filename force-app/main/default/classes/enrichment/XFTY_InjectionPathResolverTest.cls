/**
 * Proves `XFTY_InjectionPathResolver` - field tokens to relationship names,
 * against the describe. No DML/SOQL (describe calls are neither).
 */
@IsTest
private class XFTY_InjectionPathResolverTest {

    @IsTest
    static void testParentRelationshipName_forAStandardLookup_returnsTheRelationshipName() {
        // Arrange
        SObjectField lookup = Contact.AccountId;

        // Act
        Test.startTest();
        String name = XFTY_InjectionPathResolver.parentRelationshipName(lookup);
        Test.stopTest();

        // Assert
        Assert.areEqual('Account', name);
    }

    @IsTest
    static void testParentRelationshipName_forASelfLookup_returnsTheSelfRelationshipName() {
        // Arrange
        SObjectField selfLookup = Account.ParentId;

        // Act
        Test.startTest();
        String name = XFTY_InjectionPathResolver.parentRelationshipName(selfLookup);
        Test.stopTest();

        // Assert
        Assert.areEqual('Parent', name);
    }

    @IsTest
    static void testParentRelationshipName_forANonReferenceField_throws() {
        // Arrange
        SObjectField notALookup = Account.Name;

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_InjectionPathResolver.parentRelationshipName(notALookup);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('Name'), 'the message names the offending field');
    }

    @IsTest
    static void testChildRelationshipName_forALookupBackToTheParent_returnsTheSubqueryName() {
        // Arrange
        SObjectType parentType = Account.SObjectType;

        // Act
        Test.startTest();
        String name = XFTY_InjectionPathResolver.childRelationshipName(parentType, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual('Contacts', name);
    }

    @IsTest
    static void testChildRelationshipName_whenNoChildRelationshipMatches_throws() {
        // Arrange
        SObjectField notAChildLookup = Contact.Birthdate;

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_InjectionPathResolver.childRelationshipName(Account.SObjectType, notAChildLookup);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
    }
}
