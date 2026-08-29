/**
 * Coverage for `XFTY_IdMocker`, which fabricates structurally valid Salesforce
 * Ids without touching the database.
 */
@IsTest
private class XFTY_IdMockerTest {

    @IsTest
    static void generateIdCarriesTheSObjectKeyPrefix() {
        Id generated = XFTY_IdMocker.generateId(Account.SObjectType);

        String expectedPrefix = Account.SObjectType.getDescribe().getKeyPrefix();
        Assert.areEqual(expectedPrefix, String.valueOf(generated).substring(0, 3));
        Assert.areEqual(Account.SObjectType, generated.getSObjectType(), 'Id should resolve back to its type');
    }

    @IsTest
    static void generateIdProducesAValidNormalisedId() {
        Id generated = XFTY_IdMocker.generateId(Contact.SObjectType);
        // The mocker builds a 15-character key; Apex normalises it to the 18-character form.
        Assert.areEqual(18, String.valueOf(generated).length());
        Assert.areEqual(Contact.SObjectType, generated.getSObjectType());
    }

    @IsTest
    static void generateIdIsUniqueAcrossManyCalls() {
        Set<Id> generated = new Set<Id>();
        for (Integer i = 0; i < 100; i++) {
            generated.add(XFTY_IdMocker.generateId(Contact.SObjectType));
        }
        Assert.areEqual(100, generated.size(), 'Every fabricated Id must be distinct');
    }

    @IsTest
    static void addIdPopulatesTheIdField() {
        Account record = new Account(Name = 'Anything');
        Assert.isNull(record.Id);

        SObject returned = XFTY_IdMocker.addId(record);

        Assert.areEqual(record, returned, 'addId should return the same instance it was given');
        Assert.isNotNull(record.Id);
        Assert.areEqual(
                Account.SObjectType.getDescribe().getKeyPrefix(),
                String.valueOf(record.Id).substring(0, 3)
        );
    }

    @IsTest
    static void addIdsPopulatesEveryRecordWithADistinctId() {
        List<Contact> records = new List<Contact>{
                new Contact(LastName = 'A'),
                new Contact(LastName = 'B'),
                new Contact(LastName = 'C')
        };

        XFTY_IdMocker.addIds(records);

        Set<Id> ids = new Set<Id>();
        for (Contact record : records) {
            Assert.isNotNull(record.Id);
            ids.add(record.Id);
        }
        Assert.areEqual(3, ids.size());
    }

    @IsTest
    static void fabricatedIdsAreNotBackedByRealRecords() {
        Id generated = XFTY_IdMocker.generateId(Account.SObjectType);
        Assert.areEqual(0, [SELECT COUNT() FROM Account WHERE Id = :generated]);
    }
}
