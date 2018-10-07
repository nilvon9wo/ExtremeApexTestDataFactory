@IsTest
public class SAMPLE_DummySObjectSupplierTests { 
	private static final User TEST_ADMIN = XFTY_DummyUserFactoryOutlet.TEST_ADMIN_USER;
	private static final String TEST_CONTACT_FIRST_NAME = 'Fred';
 
 	// Create Bundle Tests -------------------------------------------------------------
 
	@IsTest public static void testSupplyBundleShouldCreateOnlyContact() {
    	// Arrange
    	List<Contact> templateContactList = createTestTemplateContactList();
    	
    	// Act
    	XFTY_DummySObjectBundle resultBundle; 
    	Test.startTest();
    	System.runAs(TEST_ADMIN){
	    	resultBundle = (new XFTY_DummySObjectSupplier(Contact.SObjectType))
	    		.setOverrideTemplateList(templateContactList)
	    		.setInsertMode(XFTY_InsertModeEnum.NOW)
	    		.setInclusivity(XFTY_InsertInclusivityEnum.NONE)
	    		.supplyBundle(); 
    	}	    		
    	Test.stopTest();
    	
    	// Assert
    	System.assertNotEquals(null, resultBundle);
    	assertContactsCreated(resultBundle);

    	System.assertEquals(null, resultBundle.getList(Contact.AccountId));
    	System.assertEquals(null, resultBundle.getBundle(Contact.AccountId));
		System.assertEquals(null, ((Contact) resultBundle.getList(Contact.Id)[0]).AccountId);
    }
     
	
    @IsTest public static void testContactFactoryCreatesBothContactAndAccountInDatabase() {
    	// Arrange
    	List<Contact> templateContactList = createTestTemplateContactList();
    	
    	// Act
    	XFTY_DummySObjectBundle resultBundle;
    	Test.startTest();
    	System.runAs(TEST_ADMIN){
	    	resultBundle = (new XFTY_DummySObjectSupplier(Contact.SObjectType))
	    		.setOverrideTemplateList(templateContactList)
	    		.setInsertMode(XFTY_InsertModeEnum.NOW)
	    		.setInclusivity(XFTY_InsertInclusivityEnum.ALL)
	    		.supplyBundle(); 
    	}
    	Test.stopTest();
    	
    	// Assert
	    System.assertNotEquals(null, resultBundle);
    	assertContactsCreated(resultBundle);
    	assertAccountsCreated(resultBundle);
    	
		System.assertEquals(
			((Contact) resultBundle.getList(Contact.Id)[0]).AccountId, 
			resultBundle.getList(Contact.AccountId)[0].Id
		);
		
		List<Database.SaveResult> saveResultList = Database.update(resultBundle.getList(Contact.Id));
		System.assertEquals(resultBundle.getList(Contact.Id).size(), saveResultList.size());
		for (Database.SaveResult saveResult : saveResultList) {
			System.assert(saveResult.isSuccess());
		}		
    }
    
    @IsTest public static void testContactFactoryCreatesBothContactAndAccountWithoutTouchingDatabase() {
    	// Arrange
    	List<Contact> templateContactList = createTestTemplateContactList();
    	
    	// Act
    	XFTY_DummySObjectBundle resultBundle;
    	Test.startTest();
		System.runAs(TEST_ADMIN){
	    	resultBundle = (new XFTY_DummySObjectSupplier(Contact.SObjectType))
	    		.setOverrideTemplateList(templateContactList)
	    		.setInsertMode(XFTY_InsertModeEnum.MOCK)
	    		.setInclusivity(XFTY_InsertInclusivityEnum.ALL)
	    		.supplyBundle(); 
		}
    	Test.stopTest();
    	
    	// Assert
	    System.assertNotEquals(null, resultBundle);
    	assertContactsCreated(resultBundle);
    	assertAccountsCreated(resultBundle);
    	
		System.assertEquals(
			((Contact) resultBundle.getList(Contact.Id)[0]).AccountId, 
			resultBundle.getList(Contact.AccountId)[0].Id
		);
		
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

 	// Create Instance Tests -------------------------------------------------------------
 
	@IsTest public static void testSupplyShouldCreateOnlyContactWhenTemplateIsSet() { 
    	// Arrange
    	List<Contact> templateContactList = createTestTemplateContactList();
    	
    	// Act
    	Contact resultContact; 
    	Test.startTest();
    	System.runAs(TEST_ADMIN){
	    	resultContact = (Contact) (new XFTY_DummySObjectSupplier(Contact.SObjectType))
	    		.setOverrideTemplateList(templateContactList)
	    		.setInsertMode(XFTY_InsertModeEnum.MOCK)
	    		.supply(); 
    	}	    		
    	Test.stopTest();
    	
    	// Assert 
    	System.assertNotEquals(null, resultContact);
    	assertContactCreated(resultContact);

    	System.assertEquals(null, resultContact.AccountId);
    }

	@IsTest public static void testSupplyShouldCreateOnlyContactWhenTypeIsSet() { 
    	// Arrange
    	List<Contact> templateContactList = createTestTemplateContactList();
    	
    	// Act
    	Contact resultContact; 
    	Test.startTest();
    	System.runAs(TEST_ADMIN){
	    	resultContact = (Contact) (new XFTY_DummySObjectSupplier(Contact.SObjectType))
	    		.supply(); 
    	}	    		
    	Test.stopTest();
    	
    	// Assert 
    	System.assertNotEquals(null, resultContact);
    	System.assert(resultContact.FirstName.contains(SAMPLE_DummyContactFactoryOutlet.DEFAULT_FIRST_NAME_PREFIX));
    	System.assert(resultContact.LastName.contains(SAMPLE_DummyContactFactoryOutlet.DEFAULT_LAST_NAME_PREFIX));
    }

	@IsTest public static void testSupplyShouldThrowFriendlyExceptionWhenNoSObjectTypeProvided() { 
    	// Arrange
    	List<Contact> templateContactList = createTestTemplateContactList();
    	
    	// Act
    	XFTY_DummySObjectSupplier.SanityException caughtException; 
    	Test.startTest();
    	System.runAs(TEST_ADMIN){
    		try {
    			(new XFTY_DummySObjectSupplier(null));
    		}
    		catch(XFTY_DummySObjectSupplier.SanityException ex) {
    			caughtException = ex;
    		}
    	}	    		
    	Test.stopTest();
    	 
    	// Assert 
    	System.assertNotEquals(null, caughtException);
    	System.assert(caughtException.getMessage().contains('SObjectType to request supplies'));
    }
  
   // Helpers ------------------------------------------------------------------------------------

    private static List<Contact> createTestTemplateContactList() {
    	return new List<Contact>{ 
    		new Contact(
    			FirstName = TEST_CONTACT_FIRST_NAME
    		)
    	};
    }

    private static void assertAccountsCreated(XFTY_DummySObjectBundle resultBundle) {
      	System.assertNotEquals(null, resultBundle.getBundle(Contact.AccountId));
      	List<Account> resultAccountList = (List<Account>) resultBundle.getList(Contact.AccountId);
      	System.assertNotEquals(null, resultAccountList);
		
		Account	resultAccount = resultAccountList[0];   
    	System.assertNotEquals(null, resultAccount.Id);
    	System.assert(resultAccount.Name.contains(SAMPLE_DummyAccountFactoryOutlet.DEFAULT_NAME_PREFIX));
    	System.assertEquals(resultAccount.Description, SAMPLE_DummyContactFactoryOutlet.DEFAULT_ACCOUNT_DESCRIPTION);
    }

    private static void assertContactsCreated(XFTY_DummySObjectBundle resultBundle) {
    	List<Contact> resultContactList = (List<Contact>) resultBundle.getList(Contact.Id); 
    	System.assertNotEquals(null, resultContactList);
    	assertContactCreated(resultContactList[0]); 
    }
    
    private static void assertContactCreated(Contact resultContact) {
    	System.assertNotEquals(null, resultContact.Id);
    	System.assertEquals(TEST_CONTACT_FIRST_NAME, resultContact.FirstName);
    	System.assert(resultContact.LastName.contains(SAMPLE_DummyContactFactoryOutlet.DEFAULT_LAST_NAME_PREFIX));
    }


}