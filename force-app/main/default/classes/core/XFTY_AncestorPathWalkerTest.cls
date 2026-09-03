/**
 * Proves `XFTY_AncestorPathWalker` - reading a field several relationship hops up
 * a generated ancestor graph. Pure in-memory structure, no DML/SOQL.
 */
@IsTest
private class XFTY_AncestorPathWalkerTest {

    @IsTest
    static void testRead_forAOneHopAncestorFieldAndARow_readsTheAlignedParentValue() {
        // Arrange - two Contacts, each with its own parent Account carrying a distinct name
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact(), new Contact() });
        bundle.put(Contact.AccountId, new List<SObject>{
                new Account(Name = 'Row Zero'), new Account(Name = 'Row One')
        });

        // Act
        Test.startTest();
        Object rowOneName = XFTY_AncestorPathWalker.read(
                bundle, new List<SObjectField>{ Contact.AccountId, Account.Name }, 1
        );
        Test.stopTest();

        // Assert
        Assert.areEqual('Row One', rowOneName, 'the parent aligned with row 1');
    }

    @IsTest
    static void testRead_forAMultiHopPath_descendsThroughEveryLeadingRelationship() {
        // Arrange - Contact -> Account (sub-bundle) -> parent Account (list), only the deepest name set
        XFTY_DummySObjectBundle accountBundle = new XFTY_DummySObjectBundle();
        accountBundle.put(Account.ParentId, new List<SObject>{ new Account(Name = 'Grandparent') });
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.put(Contact.AccountId, accountBundle);

        // Act
        Test.startTest();
        Object grandparentName = XFTY_AncestorPathWalker.read(
                bundle, new List<SObjectField>{ Contact.AccountId, Account.ParentId, Account.Name }, 0
        );
        Test.stopTest();

        // Assert
        Assert.areEqual('Grandparent', grandparentName);
    }

    @IsTest
    static void testRead_whenAHopWasNotGenerated_returnsNull() {
        // Arrange - the relationship the path asks for was never put
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.putPrimaries(Contact.Id, new List<SObject>{ new Contact() });

        // Act
        Test.startTest();
        Object missing = XFTY_AncestorPathWalker.read(
                bundle, new List<SObjectField>{ Contact.AccountId, Account.Name }, 0
        );
        Test.stopTest();

        // Assert
        Assert.isNull(missing, 'an ungenerated ancestor reads as null, it does not throw');
    }

    @IsTest
    static void testRead_whenTheRowIndexIsOutOfRange_returnsNull() {
        // Arrange - one parent, ask for row 5
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.put(Contact.AccountId, new List<SObject>{ new Account(Name = 'Only') });

        // Act
        Test.startTest();
        Object outOfRange = XFTY_AncestorPathWalker.read(
                bundle, new List<SObjectField>{ Contact.AccountId, Account.Name }, 5
        );
        Test.stopTest();

        // Assert
        Assert.isNull(outOfRange);
    }

    @IsTest
    static void testRead_whenTheRowIndexIsNegative_returnsNull() {
        // Arrange
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();
        bundle.put(Contact.AccountId, new List<SObject>{ new Account(Name = 'Only') });

        // Act
        Test.startTest();
        Object negative = XFTY_AncestorPathWalker.read(
                bundle, new List<SObjectField>{ Contact.AccountId, Account.Name }, -1
        );
        Test.stopTest();

        // Assert
        Assert.isNull(negative);
    }

    @IsTest
    static void testRead_whenThePathIsTooShortToWalk_throws() {
        // Arrange
        List<SObjectField> justAField = new List<SObjectField>{ Account.Name };
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_AncestorPathWalker.read(bundle, justAField, 0);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'a path needs at least one relationship hop then the field to read');
    }

    @IsTest
    static void testRead_whenAPathStepIsNull_throws() {
        // Arrange
        List<SObjectField> withNullStep = new List<SObjectField>{ Contact.AccountId, null };
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            XFTY_AncestorPathWalker.read(bundle, withNullStep, 0);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'a null path step is rejected');
    }
}
