/**
 * Proves `XFTY_InverseAlignment` - for each parent, the children pointing back at
 * it. Pure in-memory, no DML/SOQL.
 */
@IsTest
private class XFTY_InverseAlignmentTest {

    @IsTest
    static void testChildrenPerParent_whenParentsHaveIds_matchesOnTheForeignKey() {
        // Arrange
        Id one = XFTY_IdMocker.generateId(Account.SObjectType);
        Id two = XFTY_IdMocker.generateId(Account.SObjectType);
        List<SObject> parents = new List<SObject>{ new Account(Id = one), new Account(Id = two) };
        List<SObject> children = new List<SObject>{
                new Contact(AccountId = two), new Contact(AccountId = one), new Contact(AccountId = two)
        };

        // Act
        Test.startTest();
        List<List<SObject>> perParent = XFTY_InverseAlignment.childrenPerParent(parents, children, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, perParent[0].size(), 'parent one has one child');
        Assert.areEqual(2, perParent[1].size(), 'parent two has two');
    }

    @IsTest
    static void testChildrenPerParent_whenParentsHaveNoIds_matchesByPosition() {
        // Arrange
        List<SObject> parents = new List<SObject>{ new Account(), new Account() };
        List<SObject> children = new List<SObject>{ new Contact(LastName = 'A'), new Contact(LastName = 'B') };

        // Act
        Test.startTest();
        List<List<SObject>> perParent = XFTY_InverseAlignment.childrenPerParent(parents, children, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual('A', ((Contact) perParent[0][0]).LastName);
        Assert.areEqual('B', ((Contact) perParent[1][0]).LastName);
    }

    @IsTest
    static void testChildrenPerParent_whenNothingPointsAtAParent_givesItAnEmptyList() {
        // Arrange
        List<SObject> parents = new List<SObject>{ new Account(Id = XFTY_IdMocker.generateId(Account.SObjectType)) };
        List<SObject> children = new List<SObject>{
                new Contact(AccountId = XFTY_IdMocker.generateId(Account.SObjectType))
        };

        // Act
        Test.startTest();
        List<List<SObject>> perParent = XFTY_InverseAlignment.childrenPerParent(parents, children, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual(0, perParent[0].size());
    }

    @IsTest
    static void testChildrenPerParent_whenThereAreFewerChildrenThanParents_positionFallbackGivesEmpty() {
        // Arrange
        List<SObject> parents = new List<SObject>{ new Account(), new Account() };
        List<SObject> children = new List<SObject>{ new Contact(LastName = 'A') };

        // Act
        Test.startTest();
        List<List<SObject>> perParent = XFTY_InverseAlignment.childrenPerParent(parents, children, Contact.AccountId);
        Test.stopTest();

        // Assert
        Assert.areEqual(1, perParent[0].size());
        Assert.areEqual(0, perParent[1].size(), 'no child at that position');
    }
}
