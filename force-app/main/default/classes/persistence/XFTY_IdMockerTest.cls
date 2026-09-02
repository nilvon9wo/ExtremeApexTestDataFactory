/**
 * Proves `XFTY_IdMocker`, which fabricates structurally valid Salesforce Ids
 * without touching the database. `generateId` / `addId` / `addIds` do no DML; the
 * one test that queries for a real record runs under `System.runAs`.
 */
@IsTest
private class XFTY_IdMockerTest {

    @IsTest
    static void testGenerateId_carriesTheSObjectKeyPrefixAndResolvesBackToTheType() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        Id generated = XFTY_IdMocker.generateId(Account.SObjectType);
        Test.stopTest();

        // Assert
        Assert.areEqual(Account.SObjectType.getDescribe().getKeyPrefix(), String.valueOf(generated).substring(0, 3));
        Assert.areEqual(Account.SObjectType, generated.getSObjectType(), 'the Id resolves back to its type');
    }

    @IsTest
    static void testGenerateId_producesTheNormalisedEighteenCharacterForm() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        Id generated = XFTY_IdMocker.generateId(Contact.SObjectType);
        Test.stopTest();

        // Assert - the mocker builds a 15-character key; Apex normalises it to 18
        Assert.areEqual(18, String.valueOf(generated).length());
        Assert.areEqual(Contact.SObjectType, generated.getSObjectType());
    }

    @IsTest
    static void testGenerateId_isUniqueAcrossManyCalls() {
        // Arrange
        Set<Id> generated = new Set<Id>();

        // Act
        Test.startTest();
        for (Integer i = 0; i < 100; i++) {
            generated.add(XFTY_IdMocker.generateId(Contact.SObjectType));
        }
        Test.stopTest();

        // Assert
        Assert.areEqual(100, generated.size(), 'every fabricated Id is distinct');
    }

    @IsTest
    static void testAddId_populatesTheIdFieldAndReturnsTheSameInstance() {
        // Arrange
        Account record = new Account(Name = 'Anything');

        // Act
        Test.startTest();
        SObject returned = XFTY_IdMocker.addId(record);
        Test.stopTest();

        // Assert
        Assert.areEqual(record, returned, 'addId returns the same instance it was given');
        Assert.areEqual(
                Account.SObjectType.getDescribe().getKeyPrefix(),
                String.valueOf(record.Id).substring(0, 3)
        );
    }

    @IsTest
    static void testAddIds_populatesEveryRecordWithADistinctId() {
        // Arrange
        List<Contact> records = new List<Contact>{
                new Contact(LastName = 'A'), new Contact(LastName = 'B'), new Contact(LastName = 'C')
        };

        // Act
        Test.startTest();
        XFTY_IdMocker.addIds(records);
        Test.stopTest();

        // Assert
        Set<Id> ids = new Set<Id>();
        for (Contact record : records) {
            Assert.isNotNull(record.Id);
            ids.add(record.Id);
        }
        Assert.areEqual(3, ids.size());
    }

    @IsTest
    static void testGenerateId_producesIdsNotBackedByRealRecords() {
        // Arrange
        Id generated;

        // Act
        System.runAs(XFTY_DefaultUserDataProvider.TEST_ADMIN_USER) {
            Test.startTest();
            generated = XFTY_IdMocker.generateId(Account.SObjectType);
            Test.stopTest();
        }

        // Assert
        Assert.areEqual(0, [SELECT COUNT() FROM Account WHERE Id = :generated]);
    }
}
