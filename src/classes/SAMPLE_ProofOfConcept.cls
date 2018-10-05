@IsTest
public class SAMPLE_ProofOfConcept {
    @IsTest public static void testContactFactoryCreatesBothContactAndAccountInDatabase() {
    	// Arrange
    	String testName = 'Fred';
    	List<Contact> templateContactList = new List<Contact>{
    		new Contact(
    			FirstName = testName
    		)
    	};
    	
    	// Act
    	TEST_DummySObjectBundle resultBundle;
    	Test.startTest();
    	// TODO: Implement System.runAs(){}
    	resultBundle = (new SAMPLE_DummyContactFactoryOutlet()).createBundle(
    			templateContactList, 
    			TEST_InsertModeEnum.NOW, 
    			TEST_InsertInclusivityEnum.ALL
    		);
    	Test.stopTest();
    	
    	// Assert
    	System.assertNotEquals(null, resultBundle);
    	System.assertNotEquals(null, resultBundle.getList(Contact.Id));
    	System.assertNotEquals(null, resultBundle.getList(Contact.AccountId));
    	System.assertNotEquals(null, resultBundle.getBundle(Contact.AccountId));
    	
    	System.assertNotEquals(null, resultBundle.getList(Contact.Id)[0].Id);
    	System.assertEquals(testName, ((Contact) resultBundle.getList(Contact.Id)[0]).FirstName);
    	System.assertNotEquals(null, ((Contact) resultBundle.getList(Contact.Id)[0]).LastName);

    	System.assertNotEquals(null, resultBundle.getList(Contact.AccountId)[0].Id);
    	System.assert(((Account) resultBundle.getList(Contact.AccountId)[0]).Name.contains(SAMPLE_DummyAccountFactoryOutlet.DEFAULT_NAME_PREFIX));
    	
		System.assertEquals(((Contact) resultBundle.getList(Contact.Id)[0]).AccountId, resultBundle.getList(Contact.AccountId)[0].Id);
		
		List<Database.SaveResult> saveResultList = Database.update(resultBundle.getList(Contact.Id));
		System.assertEquals(resultBundle.getList(Contact.Id).size(), saveResultList.size());
		for (Database.SaveResult saveResult : saveResultList) {
			System.assert(saveResult.isSuccess());
		}		
    }

    @IsTest public static void testContactFactoryCreatesOnlyContact() {
    	// Arrange
    	String testName = 'Fred';
    	List<Contact> templateContactList = new List<Contact>{
    		new Contact(
    			FirstName = testName
    		)
    	};
    	
    	// Act
    	TEST_DummySObjectBundle resultBundle;
    	Test.startTest();
    	// TODO: Implement System.runAs(){}
    	resultBundle = (new SAMPLE_DummyContactFactoryOutlet()).createBundle(
    			templateContactList, 
    			TEST_InsertModeEnum.NOW, 
    			TEST_InsertInclusivityEnum.NONE
    		);
    	Test.stopTest();
    	
    	// Assert
    	System.assertNotEquals(null, resultBundle);
    	System.assertNotEquals(null, resultBundle.getList(Contact.Id));
    	System.assertEquals(null, resultBundle.getList(Contact.AccountId));
    	System.assertEquals(null, resultBundle.getBundle(Contact.AccountId));
    	
    	System.assertNotEquals(null, resultBundle.getList(Contact.Id)[0].Id);
    	System.assertEquals(testName, ((Contact) resultBundle.getList(Contact.Id)[0]).FirstName);
    	System.assertNotEquals(null, ((Contact) resultBundle.getList(Contact.Id)[0]).LastName);
		System.assertEquals(((Contact) resultBundle.getList(Contact.Id)[0]).AccountId, null);
    }

    @IsTest public static void testContactFactoryCreatesBothContactAndAccountWithoutTouchingDatabase() {
    	// Arrange
    	String testName = 'Fred';
    	List<Contact> templateContactList = new List<Contact>{
    		new Contact(
    			FirstName = testName
    		)
    	};
    	
    	// Act
    	TEST_DummySObjectBundle resultBundle;
    	Test.startTest();
    	// TODO: Implement System.runAs(){}
    	resultBundle = (new SAMPLE_DummyContactFactoryOutlet()).createBundle(
    			templateContactList, 
    			TEST_InsertModeEnum.MOCK, 
    			TEST_InsertInclusivityEnum.ALL
    		);
    	Test.stopTest();
    	
    	// Assert
    	System.assertNotEquals(null, resultBundle);
    	System.assertNotEquals(null, resultBundle.getList(Contact.Id));
    	System.assertNotEquals(null, resultBundle.getList(Contact.AccountId));
    	System.assertNotEquals(null, resultBundle.getBundle(Contact.AccountId));
    	
    	System.assertNotEquals(null, resultBundle.getList(Contact.Id)[0].Id);
    	System.assertEquals(testName, ((Contact) resultBundle.getList(Contact.Id)[0]).FirstName);
    	System.assertNotEquals(null, ((Contact) resultBundle.getList(Contact.Id)[0]).LastName);

    	System.assertNotEquals(null, resultBundle.getList(Contact.AccountId)[0].Id);
    	System.assert(((Account) resultBundle.getList(Contact.AccountId)[0]).Name.contains(SAMPLE_DummyAccountFactoryOutlet.DEFAULT_NAME_PREFIX));
    	
		System.assertEquals(((Contact) resultBundle.getList(Contact.Id)[0]).AccountId, resultBundle.getList(Contact.AccountId)[0].Id);
		
		DmlException caughtException;
		try {
			update resultBundle.getList(Contact.Id);
		}
		catch (DmlException ex) {
			caughtException = ex;
		}
		System.assertNotEquals(null, caughtException);
		System.assert(caughtException.getMessage().contains('INVALID_CROSS_REFERENCE_KEY'));
    }

}