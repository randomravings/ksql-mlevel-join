USE [test];
GO
INSERT INTO [location]([id],[name]) VALUES (1,N'North');
INSERT INTO [location]([id],[name]) VALUES (2,N'South');
GO
INSERT INTO [department]([id],[name],[loc_id]) VALUES (1,N'Strategy',1);
INSERT INTO [department]([id],[name],[loc_id]) VALUES (2,N'Finance',1);
INSERT INTO [department]([id],[name],[loc_id]) VALUES (3,N'Platforms',2);
INSERT INTO [department]([id],[name],[loc_id]) VALUES (4,N'Security',2);
GO
INSERT INTO [employee]([id],[name],[dep_id]) VALUES (1,N'John',1);
INSERT INTO [employee]([id],[name],[dep_id]) VALUES (2,N'Debbie',1);
INSERT INTO [employee]([id],[name],[dep_id]) VALUES (3,N'Frank',2);
INSERT INTO [employee]([id],[name],[dep_id]) VALUES (4,N'Javier',2);
INSERT INTO [employee]([id],[name],[dep_id]) VALUES (5,N'Jane',3);
INSERT INTO [employee]([id],[name],[dep_id]) VALUES (6,N'Dominic',3);
INSERT INTO [employee]([id],[name],[dep_id]) VALUES (7,N'Alice',4);
INSERT INTO [employee]([id],[name],[dep_id]) VALUES (8,N'Tracey',4);
GO
